"use client";

import { useParams } from "next/navigation";
import { useEffect, useState } from "react";
import AppShell from "@/components/AppShell";
import ClipCard from "@/components/ClipCard";
import { api } from "@/lib/api";
import type { Clip, Video } from "@/lib/types";

export default function ReviewPage() {
  const params = useParams<{ videoId: string }>();
  const [video, setVideo] = useState<Video | null>(null);
  const [clips, setClips] = useState<Clip[]>([]);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(true);

  async function load() {
    try {
      const [v, c] = await Promise.all([
        api.getVideo(params.videoId),
        api.getVideoClips(params.videoId),
      ]);
      setVideo(v);
      setClips(c);
      setError("");
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    setLoading(true);
    load();
    const interval = setInterval(load, 4000);
    return () => clearInterval(interval);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [params.videoId]);

  return (
    <AppShell>
      <h1 className="mb-1 text-3xl font-extralight tracking-tight">{video?.title || "Video"}</h1>
      <p className="mb-6 text-sm text-gray-400">
        Status: <span className="text-gray-300">{video?.status}</span>
        {video?.status === "analyzing" || video?.status === "transcribing" ? (
          <span className="ml-2 text-amber-400">Clips are being generated…</span>
        ) : null}
      </p>

      {error && <p className="mb-4 text-sm text-red-400">{error}</p>}
      {video?.error_message && <p className="mb-4 text-sm text-red-400">{video.error_message}</p>}

      {clips.length === 0 ? (
        <p className="text-sm text-gray-500">
          {loading
            ? "Loading…"
            : "No clips yet. Once analysis finishes, AI-selected clips will appear here for review."}
        </p>
      ) : (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {clips.map((clip) => (
            <ClipCard key={clip.id} clip={clip} onChange={load} />
          ))}
        </div>
      )}
    </AppShell>
  );
}
