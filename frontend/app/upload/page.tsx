"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import AppShell from "@/components/AppShell";
import UploadDropzone from "@/components/UploadDropzone";
import { api } from "@/lib/api";
import type { Video } from "@/lib/types";

const STATUS_STYLES: Record<string, string> = {
  uploaded: "bg-white/5 text-gray-300",
  transcribing: "bg-amber-500/15 text-amber-300",
  analyzing: "bg-amber-500/15 text-amber-300",
  analyzed: "bg-emerald-500/15 text-emerald-300",
  failed: "bg-red-500/15 text-red-300",
};

export default function UploadPage() {
  const [videos, setVideos] = useState<Video[]>([]);
  const [busy, setBusy] = useState(false);
  const [url, setUrl] = useState("");
  const [error, setError] = useState("");
  const [loadError, setLoadError] = useState("");
  const [loading, setLoading] = useState(true);

  async function load() {
    try {
      setVideos(await api.listVideos());
      setLoadError("");
    } catch (e) {
      setLoadError((e as Error).message);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    load();
    const interval = setInterval(load, 5000);
    return () => clearInterval(interval);
  }, []);

  async function handleFiles(files: File[]) {
    setBusy(true);
    setError("");
    try {
      for (const file of files) {
        await api.uploadVideo(file);
      }
      await load();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  async function handleImport() {
    if (!url.trim()) return;
    setBusy(true);
    setError("");
    try {
      await api.importFromUrl(url.trim());
      setUrl("");
      await load();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <AppShell>
      <h1 className="mb-6 text-3xl font-extralight tracking-tight">Upload</h1>

      <UploadDropzone onFiles={handleFiles} busy={busy} />

      <div className="my-6 flex items-center gap-3">
        <div className="h-px flex-1 bg-white/[0.06]" />
        <span className="text-xs text-gray-500">or import from a URL</span>
        <div className="h-px flex-1 bg-white/[0.06]" />
      </div>

      <div className="flex gap-2">
        <input
          className="input"
          placeholder="https://www.youtube.com/watch?v=..."
          value={url}
          onChange={(e) => setUrl(e.target.value)}
        />
        <button className="btn-primary" disabled={busy} onClick={handleImport}>
          Import
        </button>
      </div>

      {error && <p className="mt-3 text-sm text-red-400">{error}</p>}

      <span className="eyebrow mb-5 mt-12 block">Your videos</span>
      {loadError && <p className="mb-4 text-sm text-red-400">{loadError}</p>}
      <div className="card overflow-x-auto">
        <table className="w-full min-w-[560px] text-left text-sm">
          <thead className="text-xs uppercase tracking-wide text-gray-500">
            <tr>
              <th className="px-4 py-3 font-medium">Title</th>
              <th className="px-4 py-3 font-medium">Source</th>
              <th className="px-4 py-3 font-medium">Duration</th>
              <th className="px-4 py-3 font-medium">Status</th>
              <th className="px-4 py-3 font-medium"></th>
            </tr>
          </thead>
          <tbody>
            {videos.map((video) => (
              <tr key={video.id} className="border-t border-white/[0.05]">
                <td className="px-4 py-3 text-gray-100">{video.title || "Untitled"}</td>
                <td className="px-4 py-3 text-gray-500">{video.source_type}</td>
                <td className="px-4 py-3 text-gray-500">
                  {video.duration_seconds ? `${Math.round(video.duration_seconds)}s` : "—"}
                </td>
                <td className="px-4 py-3">
                  <span className={`badge ${STATUS_STYLES[video.status] || "bg-white/5"}`}>
                    {video.status}
                  </span>
                </td>
                <td className="px-4 py-3">
                  <Link href={`/review/${video.id}`} className="font-medium text-brand-400 transition hover:text-brand-300">
                    View clips →
                  </Link>
                </td>
              </tr>
            ))}
            {loading && videos.length === 0 && (
              <tr>
                <td colSpan={5} className="px-4 py-8 text-center text-gray-500">
                  Loading…
                </td>
              </tr>
            )}
            {!loading && videos.length === 0 && (
              <tr>
                <td colSpan={5} className="px-4 py-8 text-center text-gray-500">
                  No videos yet.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </AppShell>
  );
}
