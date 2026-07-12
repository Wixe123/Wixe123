import "server-only";
import { execFileSync } from "node:child_process";
import { mkdtempSync, mkdirSync, writeFileSync, existsSync, rmSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";

const EXPORTS_DIR = path.join(process.cwd(), "data", "exports");
const FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf";

const RATIO_SIZES: Record<string, [number, number]> = {
  "9:16": [720, 1280],
  "1:1": [720, 720],
  "16:9": [1280, 720],
};

function ensureDir(dir: string) {
  if (!existsSync(dir)) mkdirSync(dir, { recursive: true });
}

function wrapText(text: string, maxChars: number): string {
  const words = text.split(" ");
  const lines: string[] = [];
  let line = "";
  for (const word of words) {
    const candidate = line ? `${line} ${word}` : word;
    if (candidate.length > maxChars && line) {
      lines.push(line);
      line = word;
    } else {
      line = candidate;
    }
  }
  if (line) lines.push(line);
  return lines.join("\n");
}

export type RenderInput = {
  id: string;
  hook: string;
  cta: string;
  avatarName: string;
  voiceName: string;
  ratio: "9:16" | "1:1" | "16:9";
  colorHex1: string;
  colorHex2: string;
};

export type RenderOutput = {
  videoPath: string;
  thumbnailPath: string;
};

/**
 * Renders a genuinely playable MP4 (gradient background + the real script
 * text burned in as captions via ffmpeg drawtext) plus a PNG thumbnail.
 * This is an honest stand-in for a talking-avatar render — no lip sync or
 * voice audio — since that requires a paid provider (HeyGen/Runway/etc.)
 * and no API key is configured. See lib/ai/engine.ts for the swap-in point.
 */
export function renderProjectAssets(input: RenderInput): RenderOutput {
  ensureDir(EXPORTS_DIR);
  const [w, h] = RATIO_SIZES[input.ratio] ?? RATIO_SIZES["9:16"];
  const duration = 5;
  const fontSize = Math.round(w / 14);
  const smallFont = Math.round(w / 30);
  const tinyFont = Math.round(w / 40);

  const workDir = mkdtempSync(path.join(tmpdir(), "creatorai-render-"));
  try {
    const hookFile = path.join(workDir, "hook.txt");
    const metaFile = path.join(workDir, "meta.txt");
    const ctaFile = path.join(workDir, "cta.txt");
    const watermarkFile = path.join(workDir, "watermark.txt");

    writeFileSync(hookFile, wrapText(input.hook, Math.floor((w * 0.85) / (fontSize * 0.62))), "utf8");
    writeFileSync(metaFile, `${input.avatarName} · ${input.voiceName} voice (AI preview)`, "utf8");
    writeFileSync(ctaFile, wrapText(input.cta, Math.floor((w * 0.85) / (smallFont * 0.62))), "utf8");
    writeFileSync(watermarkFile, "CreatorAI UGC Studio", "utf8");

    const videoPath = path.join(EXPORTS_DIR, `${input.id}.mp4`);
    const thumbnailPath = path.join(EXPORTS_DIR, `${input.id}.png`);

    const filter = [
      `gradients=size=${w}x${h}:duration=${duration}:c0=${input.colorHex1}:c1=${input.colorHex2}:speed=0.015[bg]`,
      `[bg]drawtext=fontfile=${FONT}:textfile=${hookFile}:fontcolor=white:fontsize=${fontSize}:` +
        `box=1:boxcolor=black@0.32:boxborderw=24:line_spacing=10:x=(w-text_w)/2:y=(h-text_h)/2[t1]`,
      `[t1]drawtext=fontfile=${FONT}:textfile=${ctaFile}:fontcolor=white:fontsize=${smallFont}:` +
        `line_spacing=6:x=(w-text_w)/2:y=h-${Math.round(h * 0.16)}[t2]`,
      `[t2]drawtext=fontfile=${FONT}:textfile=${metaFile}:fontcolor=white@0.8:fontsize=${tinyFont}:` +
        `x=(w-text_w)/2:y=h-${Math.round(h * 0.07)}[t3]`,
      `[t3]drawtext=fontfile=${FONT}:textfile=${watermarkFile}:fontcolor=white@0.6:fontsize=${tinyFont}:` +
        `x=(w-text_w)/2:y=${Math.round(h * 0.04)}[out]`,
    ].join(";");

    execFileSync(
      "ffmpeg",
      [
        "-y",
        "-filter_complex",
        filter,
        "-map",
        "[out]",
        "-t",
        String(duration),
        "-r",
        "30",
        "-c:v",
        "libx264",
        "-preset",
        "veryfast",
        "-pix_fmt",
        "yuv420p",
        "-movflags",
        "+faststart",
        videoPath,
      ],
      { stdio: "pipe" }
    );

    execFileSync(
      "ffmpeg",
      ["-y", "-i", videoPath, "-ss", "1.5", "-vframes", "1", thumbnailPath],
      { stdio: "pipe" }
    );

    return { videoPath, thumbnailPath };
  } finally {
    rmSync(workDir, { recursive: true, force: true });
  }
}

export type ThumbnailInput = {
  style: string;
  colorHex1: string;
  colorHex2: string;
  ctrEstimate: number;
};

/** Renders a single real PNG thumbnail on demand (used by the Thumbnails page download button). */
export function renderThumbnailPng(input: ThumbnailInput): Buffer {
  const workDir = mkdtempSync(path.join(tmpdir(), "creatorai-thumb-"));
  try {
    const w = 720;
    const h = 1280;
    const styleFile = path.join(workDir, "style.txt");
    const ctrFile = path.join(workDir, "ctr.txt");
    writeFileSync(styleFile, input.style, "utf8");
    writeFileSync(ctrFile, `${input.ctrEstimate}% est. CTR`, "utf8");
    const outPath = path.join(workDir, "out.png");

    const filter = [
      `gradients=size=${w}x${h}:duration=1:c0=${input.colorHex1}:c1=${input.colorHex2}[bg]`,
      `[bg]drawtext=fontfile=${FONT}:textfile=${styleFile}:fontcolor=white:fontsize=54:` +
        `box=1:boxcolor=black@0.3:boxborderw=16:x=32:y=32[t1]`,
      `[t1]drawtext=fontfile=${FONT}:textfile=${ctrFile}:fontcolor=0x34d399:fontsize=40:` +
        `box=1:boxcolor=black@0.4:boxborderw=14:x=32:y=h-90[out]`,
    ].join(";");

    execFileSync(
      "ffmpeg",
      ["-y", "-filter_complex", filter, "-map", "[out]", "-frames:v", "1", outPath],
      { stdio: "pipe" }
    );

    return readFileSync(outPath);
  } finally {
    rmSync(workDir, { recursive: true, force: true });
  }
}
