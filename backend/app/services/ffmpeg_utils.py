"""Thin wrappers around the ffmpeg/ffprobe CLI. Real subprocess calls, no
mocking — this is the part of the pipeline that actually touches media."""
import json
import logging
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


def detect_face_center(src_path: str, start: float, duration: float) -> tuple[float, float] | None:
    """Sample a few frames in [start, start+duration] with OpenCV's Haar
    cascade face detector and return a normalized (x, y) center in [0, 1]
    to drive the vertical-crop window. Falls back to None (caller centers
    the crop) if no face is found."""
    cascade_path = cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
    detector = cv2.CascadeClassifier(cascade_path)

    cap = cv2.VideoCapture(src_path)
    if not cap.isOpened():
        return None

    fps = cap.get(cv2.CAP_PROP_FPS) or 25
    frame_w = cap.get(cv2.CAP_PROP_FRAME_WIDTH) or 1
    frame_h = cap.get(cv2.CAP_PROP_FRAME_HEIGHT) or 1

    sample_times = [start + duration * frac for frac in (0.1, 0.4, 0.7, 0.9)]
    centers: list[tuple[float, float]] = []

    for t in sample_times:
        cap.set(cv2.CAP_PROP_POS_MSEC, max(t, 0) * 1000)
        ok, frame = cap.read()
        if not ok:
            continue
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        faces = detector.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=5, minSize=(60, 60))
        if len(faces) == 0:
            continue
        # largest face wins
        x, y, w, h = max(faces, key=lambda f: f[2] * f[3])
        centers.append(((x + w / 2) / frame_w, (y + h / 2) / frame_h))

    cap.release()
    if not centers:
        return None
    arr = np.array(centers)
    return float(np.median(arr[:, 0])), float(np.median(arr[:, 1]))


def build_vertical_crop_filter(src_w: int, src_h: int, target_ratio: float, face_center_x: float | None) -> str:
    """Build an ffmpeg crop filter that reframes a landscape source to a
    vertical target ratio (default 9:16), centered on the detected face
    when available, else centered on the frame."""
    crop_w = int(src_h * target_ratio)
    crop_w = min(crop_w, src_w)
    if face_center_x is not None:
        center_px = face_center_x * src_w
    else:
        center_px = src_w / 2
    x = int(center_px - crop_w / 2)
    x = max(0, min(x, src_w - crop_w))
    return f"crop={crop_w}:{src_h}:{x}:0"


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

    face_center = detect_face_center(src_path, start, duration)
    face_x = face_center[0] if face_center else None
    crop_filter = build_vertical_crop_filter(src_w, src_h, target_ratio=9 / 16, face_center_x=face_x)

    target_w, target_h = preset["width"], preset["height"]
    video_filters = [crop_filter, f"scale={target_w}:{target_h}"]

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


def generate_thumbnail(video_path: str, out_path: str, at_seconds: float = 0.5) -> str:
    cmd = [
        "ffmpeg", "-y", "-ss", str(at_seconds), "-i", video_path,
        "-frames:v", "1", "-q:v", "2", out_path,
    ]
    _run(cmd)
    return out_path
