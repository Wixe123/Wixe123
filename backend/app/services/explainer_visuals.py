"""Vox-style visuals for a generated explainer beat: a real photo/map from
Wikimedia Commons (license-filtered to public domain / CC), a chart
rendered from real numbers the script provided, a before/after comparison,
or a big text callout. Nothing here invents data — charts and comparisons
only ever plot numbers/labels the script itself supplied.

The palette below matches Vox's own explainer look: near-black background,
a single bright yellow accent, white body text — rather than a generic
multi-color infographic palette."""
import logging
import os
import textwrap
import urllib.parse
import urllib.request

import matplotlib

matplotlib.use("Agg")
import matplotlib.image as mpimg  # noqa: E402
import matplotlib.pyplot as plt  # noqa: E402

logger = logging.getLogger(__name__)

BG = "#070707"
INK = "#FFFFFF"
ACCENT = "#FFC600"
# Bar/line colors: accent yellow first, then tints/neutrals of the same
# family so multi-series charts stay legible without breaking the
# black/yellow/white look.
PALETTE = [ACCENT, "#FFFFFF", "#B3B3B3", "#FFE066", "#8C6D00"]

# Wikimedia licenses permissive enough to reuse without asking anyone —
# anything else (or missing metadata) is skipped rather than risking a
# copyright claim on your channel.
ALLOWED_LICENSE_SUBSTRINGS = ("public domain", "cc0", "cc-by", "cc by")

WIKIMEDIA_API = "https://commons.wikimedia.org/w/api.php"


def render_chart(chart: dict, out_path: str, width_px: int = 1080, height_px: int = 1920) -> str:
    labels = chart.get("labels") or []
    values = chart.get("values") or []
    unit = chart.get("unit", "")

    fig, ax = plt.subplots(figsize=(width_px / 200, height_px / 200), dpi=200)
    fig.patch.set_facecolor(BG)
    ax.set_facecolor(BG)

    colors = [PALETTE[i % len(PALETTE)] for i in range(len(labels))]
    if chart.get("chart_type") == "line":
        ax.plot(labels, values, color=PALETTE[0], linewidth=4, marker="o", markersize=10)
        for i, v in enumerate(values):
            ax.text(i, v, f"{v}{unit}", ha="center", va="bottom", color=INK, fontsize=18, fontweight="bold")
    else:
        bars = ax.bar(labels, values, color=colors, width=0.55)
        for bar, v in zip(bars, values):
            ax.text(
                bar.get_x() + bar.get_width() / 2, bar.get_height(), f"{v:,}{unit}",
                ha="center", va="bottom", color=INK, fontsize=20, fontweight="bold",
            )

    if chart.get("title"):
        ax.set_title(chart["title"], color=INK, fontsize=20, pad=24)
    ax.tick_params(colors=INK, labelsize=16)
    ax.yaxis.set_visible(False)
    for spine in ax.spines.values():
        spine.set_visible(False)

    plt.tight_layout(pad=3)
    fig.savefig(out_path, facecolor=fig.get_facecolor())
    plt.close(fig)
    return out_path


def _fit_text(
    fig,
    ax,
    x: float,
    y: float,
    text: str,
    max_width_px: float,
    max_height_px: float,
    max_fontsize: int = 54,
    min_fontsize: int = 20,
    **text_kwargs,
):
    """Draws `text` centered at (x, y) in axes-fraction coords, wrapped and
    shrunk until its actual rendered bounding box fits within
    max_width_px/max_height_px. matplotlib's own `wrap=True` only wraps at
    whitespace using a rough estimate and never shrinks the font, so long
    text just runs off the edges or into a neighboring column — this
    measures the real rendered extent via the canvas renderer and
    iterates, which is the only reliable way to guarantee a fit.

    The average character width is measured directly at each candidate
    fontsize (rendering the whole text unwrapped, off to the side) rather
    than assumed from a fontsize multiplier — a fixed multiplier was tried
    first and was off by ~2.3x for this bold font, which meant the wrap
    width was always too generous and the loop never converged."""
    fontsize = max_fontsize
    artist = None
    renderer = fig.canvas.get_renderer()
    while fontsize >= min_fontsize:
        if artist is not None:
            artist.remove()

        probe = ax.text(
            2, 2, text, fontsize=fontsize, transform=ax.transAxes, **text_kwargs,
        )
        fig.canvas.draw()
        probe_bbox = probe.get_window_extent(renderer=renderer)
        probe.remove()
        avg_char_width = max(1.0, probe_bbox.width / max(1, len(text)))
        chars_per_line = max(1, int(max_width_px / avg_char_width))

        # Never force-break inside a word — a hard mid-word split (e.g.
        # "Plante"/"d expl"/"osives") technically fits the pixel budget but
        # reads as broken; wrapping only at whitespace and continuing to
        # shrink the font until whole words fit is what actually looks right.
        wrapped = "\n".join(textwrap.wrap(text, width=chars_per_line, break_long_words=False, break_on_hyphens=False)) or text
        artist = ax.text(
            x, y, wrapped, ha="center", va="center", fontsize=fontsize,
            transform=ax.transAxes, **text_kwargs,
        )
        fig.canvas.draw()
        bbox = artist.get_window_extent(renderer=renderer)
        if bbox.width <= max_width_px and bbox.height <= max_height_px:
            return artist
        fontsize -= 2
    return artist


def render_callout(text: str, out_path: str, width_px: int = 1080, height_px: int = 1920) -> str:
    """A big centered text card for a single striking phrase/number — no
    photo or chart needed for the point to land."""
    fig, ax = plt.subplots(figsize=(width_px / 200, height_px / 200), dpi=200)
    fig.patch.set_facecolor(BG)
    ax.set_facecolor(BG)
    ax.axis("off")
    # Matplotlib's default subplot leaves ~12% margins on every side, so
    # axes-fraction 0..1 would NOT line up with the full width_px/height_px
    # canvas that _fit_text's budgets are computed against — pin the axes
    # to the whole figure so fraction coordinates are true canvas pixels.
    ax.set_position((0, 0, 1, 1))
    # 82% of the canvas width/height, leaving a real margin on every side
    # so wrapped lines never touch — let alone run past — the frame edge.
    _fit_text(
        fig, ax, 0.5, 0.5, text,
        max_width_px=width_px * 0.82, max_height_px=height_px * 0.82,
        color=PALETTE[0], fontweight="bold",
    )
    fig.savefig(out_path, facecolor=fig.get_facecolor())
    plt.close(fig)
    return out_path


def render_comparison(comparison: dict, out_path: str, work_dir: str, index: int, width_px: int = 1080, height_px: int = 1920) -> str:
    """A Vox-style split-screen before/after: two photos (when both sides
    resolve to a real, license-clear Wikimedia image) or, failing that, two
    short text values/labels — always divided by a bold accent line, with
    a plain "before" label on the left and an emphasized "after" label on
    the right, matching Vox's own before/after bumper look."""
    left_label = (comparison.get("left_label") or "Before").strip()
    right_label = (comparison.get("right_label") or "After").strip()
    left_value = comparison.get("left_value") or ""
    right_value = comparison.get("right_value") or ""

    left_image_path = right_image_path = None
    if comparison.get("left_query") and comparison.get("right_query"):
        candidate_left = os.path.join(work_dir, f"beat_{index}_cmp_left.jpg")
        candidate_right = os.path.join(work_dir, f"beat_{index}_cmp_right.jpg")
        left_image_path = search_wikimedia_image(comparison["left_query"], candidate_left)
        right_image_path = search_wikimedia_image(comparison["right_query"], candidate_right)

    fig, ax = plt.subplots(figsize=(width_px / 200, height_px / 200), dpi=200)
    fig.patch.set_facecolor(BG)
    ax.set_facecolor(BG)
    ax.axis("off")
    # See render_callout: without this, the default subplot margins mean
    # axes-fraction/data coords (0..1) land well inside the canvas rather
    # than at its true edges, so the 0.5 divider and the per-column width
    # budgets below silently drift off their intended pixel positions.
    ax.set_position((0, 0, 1, 1))
    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1)

    if left_image_path and right_image_path:
        ax.imshow(mpimg.imread(left_image_path), extent=(0, 0.5, 0, 1), aspect="auto", zorder=1)
        ax.imshow(mpimg.imread(right_image_path), extent=(0.5, 1, 0, 1), aspect="auto", zorder=1)
    else:
        # Each half gets its own safe column (42% of the full canvas width,
        # well clear of both the center divider and the outer edge) and a
        # height budget that leaves the bottom label row untouched — the
        # old fixed fontsize=44 + wrap=True routinely ran text across the
        # divider into the other half, or into the label row below.
        _fit_text(
            fig, ax, 0.25, 0.55, left_value or left_label,
            max_width_px=width_px * 0.42, max_height_px=height_px * 0.42,
            max_fontsize=44, color=INK, fontweight="bold", zorder=2,
        )
        _fit_text(
            fig, ax, 0.75, 0.55, right_value or right_label,
            max_width_px=width_px * 0.42, max_height_px=height_px * 0.42,
            max_fontsize=44, color=ACCENT, fontweight="bold", zorder=2,
        )

    ax.axvline(0.5, color=ACCENT, linewidth=5, zorder=3)
    _fit_text(
        fig, ax, 0.25, 0.07, left_label.upper(),
        max_width_px=width_px * 0.42, max_height_px=height_px * 0.06,
        max_fontsize=22, min_fontsize=12, color=INK, fontweight="bold", zorder=4,
    )
    _fit_text(
        fig, ax, 0.75, 0.07, right_label.upper(),
        max_width_px=width_px * 0.42, max_height_px=height_px * 0.06,
        max_fontsize=26, min_fontsize=12, color=ACCENT, fontweight="bold", style="italic", zorder=4,
    )

    fig.savefig(out_path, facecolor=fig.get_facecolor())
    plt.close(fig)
    return out_path


def search_wikimedia_image(query: str, out_path: str, timeout: int = 15) -> str | None:
    """Searches Wikimedia Commons for a photo/map matching `query` and
    downloads the first result whose license is clearly permissive.
    Returns None (caller falls back to a callout) if nothing usable is
    found — never guesses on an unclear license.

    Blocked from this development sandbox's network policy (Wikimedia's
    domain isn't on the egress allowlist here) — verify this against the
    real API once running outside the sandbox."""
    params = {
        "action": "query",
        "format": "json",
        "generator": "search",
        "gsrsearch": query,
        "gsrnamespace": "6",
        "gsrlimit": "6",
        "prop": "imageinfo",
        "iiprop": "url|extmetadata|mime",
        "iiurlwidth": "1600",
    }
    url = f"{WIKIMEDIA_API}?{urllib.parse.urlencode(params)}"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "ShortsForge/1.0 (personal project)"})
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            import json

            data = json.load(resp)
    except Exception as exc:  # noqa: BLE001
        logger.warning("Wikimedia search failed for %r: %s", query, exc)
        return None

    pages = (data.get("query") or {}).get("pages") or {}
    for page in pages.values():
        infos = page.get("imageinfo") or []
        if not infos:
            continue
        info = infos[0]
        mime = info.get("mime", "")
        if not mime.startswith("image/") or mime == "image/svg+xml":
            continue
        license_name = (info.get("extmetadata", {}).get("LicenseShortName", {}) or {}).get("value", "").lower()
        if not any(s in license_name for s in ALLOWED_LICENSE_SUBSTRINGS):
            continue
        image_url = info.get("thumburl") or info.get("url")
        if not image_url:
            continue
        try:
            img_req = urllib.request.Request(image_url, headers={"User-Agent": "ShortsForge/1.0 (personal project)"})
            with urllib.request.urlopen(img_req, timeout=timeout) as resp, open(out_path, "wb") as f:
                f.write(resp.read())
            return out_path
        except Exception as exc:  # noqa: BLE001
            logger.warning("Wikimedia image download failed for %r: %s", query, exc)
            continue
    return None


def resolve_beat_visual(beat: dict, work_dir: str, index: int) -> tuple[str, str]:
    """Returns (kind, image_path) for one beat — kind is "photo" (pans/
    zooms) or "static" (chart/callout, held still). Falls back to a
    callout of the narration itself if an image search comes up empty."""
    visual = beat.get("visual") or {}
    vtype = visual.get("type")

    if vtype == "chart" and visual.get("labels") and visual.get("values"):
        path = os.path.join(work_dir, f"beat_{index}_chart.png")
        render_chart(visual, path)
        return "static", path

    if vtype == "image" and visual.get("query"):
        path = os.path.join(work_dir, f"beat_{index}_photo.jpg")
        found = search_wikimedia_image(visual["query"], path)
        if found:
            return "photo", found

    if vtype == "comparison" and visual.get("left_label") and visual.get("right_label"):
        path = os.path.join(work_dir, f"beat_{index}_comparison.png")
        render_comparison(visual, path, work_dir, index)
        return "static", path

    text = visual.get("text") or beat.get("narration", "")[:80]
    path = os.path.join(work_dir, f"beat_{index}_callout.png")
    render_callout(text, path)
    return "static", path
