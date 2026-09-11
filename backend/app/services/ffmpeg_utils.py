"""Thin wrappers around the ffmpeg/ffprobe CLI. Real subprocess calls, no
mocking — this is the part of the pipeline that actually touches media."""
import json
import logging
import os
import subprocess

import cv2
import numpy as np

logger = logging.getLogger(__name__)

QUALITY_PRESETS = {
    "720p": {"height": 1280, "width": 720, "bitrate": "4M"},
    "1080p": {"height": 1920, "width": 1080, "bitrate": "8M"},
    "4k": {"height": 3840, "width": 2160, "bitrate": "24M"},
}


def _run(cmd: list[str]) -> subprocess.CompletedProcess:
    logger.info("ffmpeg cmd: %s", " ".join(cmd))
    return subprocess.run(cmd, capture_output=True, text=True, check=True)


def probe(path: str) -> dict:
    cmd = [
        "ffprobe", "-v", "error", "-print_format", "json",
        "-show_format", "-show_streams", path,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, check=True)
    return json.loads(result.stdout)


def get_duration_seconds(path: str) -> float:
    info = probe(path)
    return float(info.get("format", {}).get("duration", 0.0))


def extract_audio(src_path: str, out_wav_path: str) -> str:
    cmd = [
        "ffmpeg", "-y", "-i", src_path,
        "-vn", "-ac", "1", "-ar", "16000", "-f", "wav", out_wav_path,
    ]
    _run(cmd)
    return out_wav_path


def detect_face_track(
    src_path: str, start: float, duration: float, segment_s: float = 3.0, max_segments: int = 12
) -> list[tuple[float, float]]:
    """Samples faces across [start, start+duration] with OpenCV's Haar
    cascade detector in `segment_s`-second windows, returning one
    (offset_seconds, normalized_x_center) point per window where a face
    was found. offset_seconds is relative to the clip start (0..duration).
    Segments with no detected face are simply omitted — the caller
    interpolates between whatever points remain. Returns an empty list
    when nothing was found at all (caller falls back to a centered crop)."""
    cascade_path = cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
    detector = cv2.CascadeClassifier(cascade_path)

    cap = cv2.VideoCapture(src_path)
    if not cap.isOpened():
        return []

    frame_w = cap.get(cv2.CAP_PROP_FRAME_WIDTH) or 1
    num_segments = max(1, min(round(duration / segment_s), max_segments))

    points: list[tuple[float, float]] = []
    for i in range(num_segments):
        seg_offset = duration * i / num_segments
        seg_dur = duration / num_segments
        xs = []
        for frac in (0.3, 0.6):
            cap.set(cv2.CAP_PROP_POS_MSEC, max(start + seg_offset + seg_dur * frac, 0) * 1000)
            ok, frame = cap.read()
            if not ok:
                continue
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            faces = detector.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=5, minSize=(60, 60))
            if len(faces) == 0:
                continue
            # largest face wins
            x, y, w, h = max(faces, key=lambda f: f[2] * f[3])
            xs.append((x + w / 2) / frame_w)
        if xs:
            points.append((seg_offset, float(np.median(xs))))

    cap.release()
    return points


def _piecewise_linear_expr(points: list[tuple[float, float]]) -> str:
    """Builds an ffmpeg eval expression in `t` that linearly interpolates
    between (time, value) points, holding the first/last value outside the
    covered range. Commas inside the expression are backslash-escaped since
    the caller embeds this inside a comma-separated ffmpeg filter chain."""
    points = sorted(points)
    expr = f"{points[-1][1]:.4f}"
    for (t0, v0), (t1, v1) in reversed(list(zip(points, points[1:]))):
        segment = f"({v0:.4f}+({v1:.4f}-{v0:.4f})*(t-{t0:.4f})/({t1:.4f}-{t0:.4f}))"
        expr = f"if(lt(t\\,{t1:.4f})\\,{segment}\\,{expr})"
    return expr


def build_vertical_crop_filter(
    src_w: int, src_h: int, target_ratio: float, face_track: list[tuple[float, float]] | None
) -> str:
    """Build an ffmpeg crop filter that reframes a landscape source to a
    vertical target ratio (default 9:16). With two or more face-track
    points the crop pans smoothly between them over the clip's duration —
    following the subject through movement or a cut — instead of locking
    to one static position for the whole clip. Falls back to a single
    centered (or single-point) crop when there's nothing to pan between."""
    crop_w = int(src_h * target_ratio)
    crop_w = min(crop_w, src_w)

    if not face_track:
        x = int(src_w / 2 - crop_w / 2)
        return f"crop={crop_w}:{src_h}:{x}:0"

    if len(face_track) == 1:
        center_px = face_track[0][1] * src_w
        x = int(max(0, min(center_px - crop_w / 2, src_w - crop_w)))
        return f"crop={crop_w}:{src_h}:{x}:0"

    center_expr = _piecewise_linear_expr(face_track)
    x_expr = f"clip(({center_expr})*{src_w}-{crop_w}/2\\,0\\,{src_w - crop_w})"
    return f"crop={crop_w}:{src_h}:{x_expr}:0"


def detect_silences(path: str, noise_db: float = -35.0, min_silence_s: float = 0.6) -> list[tuple[float, float]]:
    """Run ffmpeg's silencedetect filter and parse silence_start/silence_end
    pairs from stderr."""
    cmd = [
        "ffmpeg", "-i", path, "-af",
        f"silencedetect=noise={noise_db}dB:d={min_silence_s}",
        "-f", "null", "-",
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    silences: list[tuple[float, float]] = []
    start = None
    for line in result.stderr.splitlines():
        if "silence_start" in line:
            try:
                start = float(line.split("silence_start:")[1].strip().split(" ")[0])
            except (IndexError, ValueError):
                start = None
        elif "silence_end" in line and start is not None:
            try:
                end = float(line.split("silence_end:")[1].strip().split(" ")[0].split("|")[0])
                silences.append((start, end))
            except (IndexError, ValueError):
                pass
            start = None
    return silences


def _silence_keep_expr(duration: float, silences: list[tuple[float, float]], keep_padding_s: float = 0.15) -> str | None:
    """Turn detected silence ranges into a `between()` gate expression for
    `select`/`aselect` that keeps everything except the silent segments
    (minus a small padding to avoid clipping speech onsets). The same
    expression must be applied to both the video and audio filter chains
    so they stay in sync after frames/samples are dropped."""
    if not silences:
        return None
    keep_ranges: list[tuple[float, float]] = []
    cursor = 0.0
    for s, e in silences:
        s = max(0.0, s + keep_padding_s)
        e = max(0.0, e - keep_padding_s)
        if s > cursor:
            keep_ranges.append((cursor, s))
        cursor = max(cursor, e)
    if cursor < duration:
        keep_ranges.append((cursor, duration))
    keep_ranges = [(s, e) for s, e in keep_ranges if e - s > 0.05]
    if not keep_ranges:
        return None
    return "+".join(f"between(t,{s:.3f},{e:.3f})" for s, e in keep_ranges)


def render_clip(
    src_path: str,
    out_path: str,
    start: float,
    end: float,
    subtitle_ass_path: str | None,
    watermark_path: str | None,
    quality: str = "1080p",
    remove_silence: bool = True,
    normalize_audio: bool = True,
) -> None:
    """The main render step: trim to [start, end], reframe to 9:16 around
    the detected face, optionally drop silence, burn subtitles, overlay a
    watermark, and normalize loudness."""
    preset = QUALITY_PRESETS.get(quality, QUALITY_PRESETS["1080p"])
    duration = end - start

    info = probe(src_path)
    video_stream = next(s for s in info["streams"] if s["codec_type"] == "video")
    has_audio = any(s["codec_type"] == "audio" for s in info["streams"])
    src_w, src_h = int(video_stream["width"]), int(video_stream["height"])

    face_track = detect_face_track(src_path, start, duration)
    crop_filter = build_vertical_crop_filter(src_w, src_h, target_ratio=9 / 16, face_track=face_track)

    target_w, target_h = preset["width"], preset["height"]
    # Subtle contrast/saturation lift — the flat, slightly washed-out look
    # of a raw webcam/screen recording reads as "amateur" next to edited
    # Shorts; this pushes it toward a more finished, punchier look by
    # default on every render.
    video_filters = [crop_filter, f"scale={target_w}:{target_h}", "eq=contrast=1.06:saturation=1.15"]

    # Silence removal must drop the same time ranges from video and audio,
    # or the two drift out of sync — so both get the same `between()` gate,
    # built once and applied to each stream's own select/aselect filter.
    select_expr = None
    if remove_silence:
        silences = detect_silences(src_path)
        clipped = [(max(s, start) - start, min(e, end) - start) for s, e in silences if e > start and s < end]
        select_expr = _silence_keep_expr(duration, clipped)

    if select_expr:
        video_filters.append(f"select='{select_expr}'")
        video_filters.append("setpts=N/FRAME_RATE/TB")

    if subtitle_ass_path:
        escaped = subtitle_ass_path.replace(":", "\\:")
        video_filters.append(f"subtitles='{escaped}'")

    cmd = [
        "ffmpeg", "-y", "-ss", str(start), "-to", str(end), "-i", src_path,
    ]
    if watermark_path:
        cmd += ["-i", watermark_path]

    chains = [f"[0:v]{','.join(video_filters)}[vbase]"]
    video_out_label = "[vbase]"
    if watermark_path:
        chains.append(f"{video_out_label}[1:v]overlay=W-w-24:H-h-24[voverlay]")
        video_out_label = "[voverlay]"

    audio_out_label = None
    if has_audio:
        audio_filters = []
        if select_expr:
            audio_filters.append(f"aselect='{select_expr}'")
            audio_filters.append("asetpts=N/SR/TB")
        if normalize_audio:
            # Compress before loudnorm so quiet/loud words in the same clip
            # land closer together first — loudnorm alone matches the
            # *average* level but leaves the raw dynamic range intact,
            # which is what makes unedited speech sound thin next to
            # produced Shorts audio.
            audio_filters.append("acompressor=threshold=-18dB:ratio=3:attack=5:release=50")
            audio_filters.append("loudnorm=I=-16:TP=-1.5:LRA=11")
        if audio_filters:
            chains.append(f"[0:a]{','.join(audio_filters)}[abase]")
            audio_out_label = "[abase]"
        else:
            audio_out_label = "0:a"

    filter_complex = ";".join(chains)

    cmd += ["-filter_complex", filter_complex, "-map", video_out_label]
    if audio_out_label:
        cmd += ["-map", audio_out_label]

    cmd += [
        "-c:v", "libx264", "-preset", "veryfast", "-b:v", preset["bitrate"],
        "-c:a", "aac", "-b:a", "192k",
        out_path,
    ]
    _run(cmd)


def _render_beat_segment(image_path: str, duration: float, out_path: str, target_w: int, target_h: int) -> None:
    """A slow Ken Burns pan/zoom over one still image (a chart, a stat
    callout, or a real photo) for exactly `duration` seconds — the
    background for one script "beat" in a generated explainer video."""
    work_w, work_h = target_w * 2, target_h * 2
    cmd = [
        "ffmpeg", "-y", "-loop", "1", "-i", image_path, "-t", str(duration),
        "-vf",
        f"scale={work_w}:{work_h}:force_original_aspect_ratio=increase,"
        f"crop={work_w}:{work_h},"
        "zoompan=z='min(zoom+0.0015,1.15)':d=1:"
        f"x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s={target_w}x{target_h}:fps=30,format=yuv420p",
        "-c:v", "libx264", "-preset", "veryfast", "-crf", "20",
        out_path,
    ]
    _run(cmd)


def _concat_segments(segment_paths: list[str], out_path: str) -> None:
    list_file = out_path + ".txt"
    with open(list_file, "w") as f:
        for p in segment_paths:
            f.write(f"file '{p}'\n")
    cmd = ["ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", list_file, "-c", "copy", out_path]
    _run(cmd)


def assemble_explainer_video(
    beat_segments: list[tuple[str, float]],
    narration_path: str,
    out_path: str,
    subtitle_ass_path: str | None,
    watermark_path: str | None,
    work_dir: str,
    quality: str = "1080p",
) -> None:
    """Builds a from-scratch Vox-style Short: a Ken Burns pass over each
    beat's still (chart/callout/photo) for exactly that beat's duration,
    concatenated back-to-back to match the narration's total length, with
    narration audio muxed in and captions/watermark burned on top."""
    preset = QUALITY_PRESETS.get(quality, QUALITY_PRESETS["1080p"])
    target_w, target_h = preset["width"], preset["height"]

    if not beat_segments:
        raise RuntimeError("No beat visuals to assemble a video from.")

    segment_paths = []
    for i, (image_path, duration) in enumerate(beat_segments):
        seg_path = os.path.join(work_dir, f"seg_{i}.mp4")
        _render_beat_segment(image_path, max(duration, 0.5), seg_path, target_w, target_h)
        segment_paths.append(seg_path)

    concat_path = os.path.join(work_dir, "bg_concat.mp4")
    _concat_segments(segment_paths, concat_path)

    video_filters = ["eq=contrast=1.05:saturation=1.1"]
    if subtitle_ass_path:
        escaped = subtitle_ass_path.replace(":", "\\:")
        video_filters.append(f"subtitles='{escaped}'")

    cmd = ["ffmpeg", "-y", "-i", concat_path, "-i", narration_path]
    if watermark_path:
        cmd += ["-i", watermark_path]

    chains = [f"[0:v]{','.join(video_filters)}[vbase]"]
    video_out_label = "[vbase]"
    if watermark_path:
        chains.append(f"{video_out_label}[2:v]overlay=W-w-24:H-h-24[voverlay]")
        video_out_label = "[voverlay]"
    chains.append(
        "[1:a]acompressor=threshold=-18dB:ratio=3:attack=5:release=50,loudnorm=I=-16:TP=-1.5:LRA=11[abase]"
    )

    cmd += [
        "-filter_complex", ";".join(chains),
        "-map", video_out_label, "-map", "[abase]",
        "-c:v", "libx264", "-preset", "veryfast", "-b:v", preset["bitrate"],
        "-c:a", "aac", "-b:a", "192k",
        "-shortest",
        out_path,
    ]
    _run(cmd)


def generate_thumbnail(video_path: str, out_path: str, at_seconds: float = 0.5) -> str:
    cmd = [
        "ffmpeg", "-y", "-ss", str(at_seconds), "-i", video_path,
        "-frames:v", "1", "-q:v", "2", out_path,
    ]
    _run(cmd)
    return out_path
