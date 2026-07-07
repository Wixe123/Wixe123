"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import AppShell from "@/components/AppShell";
import UploadDropzone from "@/components/UploadDropzone";
import { api } from "@/lib/api";
import type { Video } from "@/lib/types";

const STATUS_STYLES: Record<string, string> = {
  uploaded: "bg-base-800 text-gray-300",
  transcribing: "bg-amber-950 text-amber-300",
  analyzing: "bg-amber-950 text-amber-300",
  analyzed: "bg-emerald-950 text-emerald-300",
  failed: "bg-red-950 text-red-300",
};

export default function UploadPage() {
  const [videos, setVideos] = useState<Video[]>([]);
  const [busy, setBusy] = useState(false);
  const [url, setUrl] = useState("");
  const [error, setError] = useState("");

  async function load() {
    setVideos(await api.listVideos());
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
      <h1 className="mb-6 text-2xl font-semibold">Upload</h1>

      <UploadDropzone onFiles={handleFiles} busy={busy} />

      <div className="my-6 flex items-center gap-3">
        <div className="h-px flex-1 bg-base-700" />
        <span className="text-xs text-gray-500">or import from a URL</span>
        <div className="h-px flex-1 bg-base-700" />
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

      <h2 className="mb-3 mt-10 text-lg font-medium">Your videos</h2>
      <div className="card overflow-x-auto">
        <table className="w-full min-w-[560px] text-left text-sm">
          <thead className="bg-base-800 text-gray-400">
            <tr>
              <th className="px-4 py-2 font-medium">Title</th>
              <th className="px-4 py-2 font-medium">Source</th>
              <th className="px-4 py-2 font-medium">Duration</th>
              <th className="px-4 py-2 font-medium">Status</th>
              <th className="px-4 py-2 font-medium"></th>
            </tr>
          </thead>
          <tbody>
            {videos.map((video) => (
              <tr key={video.id} className="border-t border-base-800">
                <td className="px-4 py-2">{video.title || "Untitled"}</td>
                <td className="px-4 py-2 text-gray-500">{video.source_type}</td>
                <td className="px-4 py-2 text-gray-500">
                  {video.duration_seconds ? `${Math.round(video.duration_seconds)}s` : "—"}
                </td>
                <td className="px-4 py-2">
                  <span className={`badge ${STATUS_STYLES[video.status] || "bg-base-800"}`}>
                    {video.status}
                  </span>
                </td>
                <td className="px-4 py-2">
                  <Link href={`/review/${video.id}`} className="text-brand-400 hover:underline">
                    View clips →
                  </Link>
                </td>
              </tr>
            ))}
            {videos.length === 0 && (
              <tr>
                <td colSpan={5} className="px-4 py-6 text-center text-gray-500">
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
