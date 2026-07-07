"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import AppShell from "@/components/AppShell";
import StatCard from "@/components/StatCard";
import ClipCard from "@/components/ClipCard";
import { api } from "@/lib/api";
import type { Clip, DashboardStats, ProcessingJob } from "@/lib/types";

function bytesToGb(bytes: number): string {
  return (bytes / 1024 ** 3).toFixed(1);
}

export default function DashboardPage() {
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [reviewClips, setReviewClips] = useState<Clip[]>([]);
  const [jobs, setJobs] = useState<ProcessingJob[]>([]);
  const [error, setError] = useState("");

  async function load() {
    try {
      const [s, clips, jobList] = await Promise.all([
        api.dashboardStats(),
        api.listClips("ready_for_review"),
        api.listJobs(),
      ]);
      setStats(s);
      setReviewClips(clips.slice(0, 6));
      setJobs(jobList.slice(0, 8));
    } catch (e) {
      setError((e as Error).message);
    }
  }

  useEffect(() => {
    load();
    const interval = setInterval(load, 5000);
    return () => clearInterval(interval);
  }, []);

  return (
    <AppShell>
      <div className="mb-8 flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold">Dashboard</h1>
          <p className="text-sm text-gray-400">Today's activity across your Shorts pipeline.</p>
        </div>
        <Link href="/upload" className="btn-primary">
          + New video
        </Link>
      </div>

      {error && <p className="mb-4 text-sm text-red-400">{error}</p>}

      {stats && (
        <div className="mb-8 grid grid-cols-2 gap-4 md:grid-cols-4">
          <StatCard label="Videos today" value={stats.videos_today} icon="🎬" />
          <StatCard label="Shorts created today" value={stats.shorts_created_today} icon="✂️" />
          <StatCard label="Queue length" value={stats.queue_length} icon="🗂️" />
          <StatCard label="Processing now" value={stats.processing_count} icon="⚙️" />
          <StatCard label="Failed jobs" value={stats.failed_count} icon="⚠️" tone={stats.failed_count > 0 ? "danger" : "default"} />
          <StatCard label="Uploaded today" value={stats.uploaded_today} icon="📤" tone="success" />
          <StatCard
            label="Storage used"
            value={`${bytesToGb(stats.storage_used_bytes)} / ${bytesToGb(stats.storage_quota_bytes)} GB`}
            icon="💾"
          />
          <StatCard label="YouTube uploads today" value={stats.api_calls_today} icon="🔌" />
        </div>
      )}

      <div className="mb-4 flex items-center justify-between">
        <h2 className="text-lg font-medium">Needs your review</h2>
        <Link href="/queue" className="text-sm text-brand-400 hover:underline">
          View full queue →
        </Link>
      </div>
      {reviewClips.length === 0 ? (
        <p className="mb-8 text-sm text-gray-500">Nothing waiting for review right now.</p>
      ) : (
        <div className="mb-8 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {reviewClips.map((clip) => (
            <ClipCard key={clip.id} clip={clip} onChange={load} />
          ))}
        </div>
      )}

      <h2 className="mb-4 text-lg font-medium">Recent jobs</h2>
      <div className="card overflow-x-auto">
        <table className="w-full min-w-[560px] text-left text-sm">
          <thead className="bg-base-800 text-gray-400">
            <tr>
              <th className="px-4 py-2 font-medium">Type</th>
              <th className="px-4 py-2 font-medium">Status</th>
              <th className="px-4 py-2 font-medium">Progress</th>
              <th className="px-4 py-2 font-medium">Updated</th>
            </tr>
          </thead>
          <tbody>
            {jobs.map((job) => (
              <tr key={job.id} className="border-t border-base-800">
                <td className="px-4 py-2">{job.job_type}</td>
                <td className="px-4 py-2">
                  <span
                    className={`badge ${
                      job.status === "failed"
                        ? "bg-red-950 text-red-300"
                        : job.status === "success"
                        ? "bg-emerald-950 text-emerald-300"
                        : job.status === "running"
                        ? "bg-amber-950 text-amber-300"
                        : "bg-base-800 text-gray-300"
                    }`}
                  >
                    {job.status}
                  </span>
                </td>
                <td className="px-4 py-2">{Math.round(job.progress * 100)}%</td>
                <td className="px-4 py-2 text-gray-500">{new Date(job.updated_at).toLocaleTimeString()}</td>
              </tr>
            ))}
            {jobs.length === 0 && (
              <tr>
                <td colSpan={4} className="px-4 py-6 text-center text-gray-500">
                  No jobs yet — upload a video to get started.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </AppShell>
  );
}
