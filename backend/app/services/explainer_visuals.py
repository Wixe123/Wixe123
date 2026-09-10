"""Vox-style visuals for a generated explainer beat: a real photo/map from
Wikimedia Commons (license-filtered to public domain / CC), a chart
rendered from real numbers the script provided, or a big text callout.
Nothing here invents data — charts only ever plot numbers the script
itself supplied."""
import logging
import os
import urllib.parse
import urllib.request

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

logger = logging.getLogger(__name__)

PALETTE = ["#f3b54c", "#6fa8dc", "#8fd4a0", "#e2685a", "#c9a0e0"]
BG = "#0f1220"
INK = "#ece7da"

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


def render_callout(text: str, out_path: str, width_px: int = 1080, height_px: int = 1920) -> str:
    """A big centered text card for a single striking phrase/number — no
    photo or chart needed for the point to land."""
    fig, ax = plt.subplots(figsize=(width_px / 200, height_px / 200), dpi=200)
    fig.patch.set_facecolor(BG)
    ax.set_facecolor(BG)
    ax.axis("off")
    ax.text(
        0.5, 0.5, text, ha="center", va="center", color=PALETTE[0],
        fontsize=54, fontweight="bold", wrap=True, transform=ax.transAxes,
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

    text = visual.get("text") or beat.get("narration", "")[:80]
    path = os.path.join(work_dir, f"beat_{index}_callout.png")
    render_callout(text, path)
    return "static", path
