"use client";

import { useState } from "react";
import { api } from "@/lib/api";
import type { Clip } from "@/lib/types";

const STATUS_STYLES: Record<string, string> = {
  pending_render: "bg-base-800 text-gray-300",
  rendering: "bg-amber-950 text-amber-300",
  ready_for_review: "bg-sky-950 text-sky-300",
  approved: "bg-violet-950 text-violet-300",
  scheduled: "bg-violet-950 text-violet-300",
  uploading: "bg-amber-950 text-amber-300",
  uploaded: "bg-emerald-950 text-emerald-300",
  failed: "bg-red-950 text-red-300",
  rejected: "bg-base-800 text-gray-500",
};

function formatDuration(start: number, end: number): string {
  const s = Math.round(end - start);
  return `${s}s`;
}

export default function ClipCard({ clip, onChange }: { clip: Clip; onChange: () => void }) {
  const [busy, setBusy] = useState(false);
  const [expanded, setExpanded] = useState(false);

  async function act(fn: () => Promise<unknown>) {
    setBusy(true);
    try {
      await fn();
      onChange();
    } catch (e) {
      alert((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="card overflow-hidden">
      <div className="relative aspect-[9/16] max-h-64 w-full bg-base-800">
        {clip.thumbnail_path ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={api.clipThumbnailUrl(clip.id)}
            alt=""
            className="h-full w-full object-cover"
          />
        ) : (
          <div className="flex h-full items-center justify-center text-sm text-gray-500">
            Rendering…
          </div>
        )}
        <span className="absolute left-2 top-2 rounded-full bg-black/60 px-2 py-0.5 text-xs">
          {formatDuration(clip.start_seconds, clip.end_seconds)}
        </span>
        <span className={`badge absolute right-2 top-2 ${STATUS_STYLES[clip.status] || "bg-base-800"}`}>
          {clip.status.replace(/_/g, " ")}
        </span>
      </div>
      <div className="p-4">
        <p className="line-clamp-2 text-sm font-medium">{clip.title || "Untitled clip"}</p>
        <div className="mt-1 flex items-center gap-2 text-xs text-gray-500">
          <span>Score {clip.score.toFixed(1)}</span>
          <span>·</span>
          <span>SEO {clip.seo_score.toFixed(0)}</span>
        </div>
        {clip.score_reasons.length > 0 && (
          <div className="mt-2 flex flex-wrap gap-1">
            {clip.score_reasons.slice(0, 3).map((r) => (
              <span key={r} className="badge bg-base-800 text-gray-400">
                {r}
              </span>
            ))}
          </div>
        )}

        <button
          onClick={() => setExpanded((v) => !v)}
          className="mt-3 text-xs text-brand-400 hover:underline"
        >
          {expanded ? "Hide details" : "Edit metadata"}
        </button>

        {expanded && (
          <div className="mt-2 space-y-2">
            <input
              className="input text-sm"
              defaultValue={clip.title}
              placeholder="Title"
              onBlur={(e) => act(() => api.updateClip(clip.id, { title: e.target.value }))}
            />
            <textarea
              className="input text-sm"
              rows={2}
              defaultValue={clip.description}
              placeholder="Description"
              onBlur={(e) => act(() => api.updateClip(clip.id, { description: e.target.value }))}
            />
          </div>
        )}

        <div className="mt-4 flex flex-wrap gap-2">
          {clip.status === "ready_for_review" && (
            <>
              <button disabled={busy} className="btn-primary flex-1" onClick={() => act(() => api.approveClip(clip.id))}>
                Approve
              </button>
              <button disabled={busy} className="btn-secondary" onClick={() => act(() => api.rejectClip(clip.id))}>
                Reject
              </button>
            </>
          )}
          {clip.status === "approved" && (
            <button disabled={busy} className="btn-primary flex-1" onClick={() => act(() => api.uploadClip(clip.id))}>
              Upload to YouTube
            </button>
          )}
          {clip.status === "failed" && (
            <button disabled={busy} className="btn-secondary flex-1" onClick={() => act(() => api.retryRender(clip.id))}>
              Retry render
            </button>
          )}
          {clip.status === "uploaded" && clip.youtube_video_id && (
            <a
              href={`https://youtube.com/watch?v=${clip.youtube_video_id}`}
              target="_blank"
              rel="noreferrer"
              className="btn-secondary flex-1 text-center"
            >
              View on YouTube
            </a>
          )}
        </div>
      </div>
    </div>
  );
}
