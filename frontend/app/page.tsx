"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import AppShell from "@/components/AppShell";
import StatCard from "@/components/StatCard";
import ClipCard from "@/components/ClipCard";
import {
  IconAlertTriangle,
  IconClapperboard,
  IconDatabase,
  IconPlug,
  IconQueue,
  IconScissors,
  IconSettings,
  IconUploadCloud,
} from "@/components/icons";
import { api } from "@/lib/api";
import type { Clip, DashboardStats, ProcessingJob } from "@/lib/types";

function bytesToGb(bytes: number): string {
  return (bytes / 1024 ** 3).toFixed(1);
}

const JOB_STATUS_DOT: Record<string, string> = {
  failed: "bg-red-400",
  success: "bg-emerald-400",
  running: "bg-amber-400",
  queued: "bg-gray-500",
  paused: "bg-gray-500",
  cancelled: "bg-gray-600",
};

const JOB_STATUS_BADGE: Record<string, string> = {
  failed: "bg-red-500/10 text-red-300",
  success: "bg-emerald-500/10 text-emerald-300",
  running: "bg-amber-500/10 text-amber-300",
  queued: "bg-white/5 text-gray-300",
  paused: "bg-white/5 text-gray-400",
  cancelled: "bg-white/5 text-gray-500",
};

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
      <div className="mb-8 flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Dashboard</h1>
          <p className="mt-1 text-sm text-gray-400">Today&apos;s activity across your Shorts pipeline.</p>
        </div>
        <Link href="/upload" className="btn-primary self-start sm:self-auto">
          + New video
        </Link>
      </div>

      {error && <p className="mb-4 text-sm text-red-400">{error}</p>}

      {stats && (
        <div className="mb-10 grid grid-cols-2 gap-4 md:grid-cols-4">
          <StatCard label="Videos today" value={stats.videos_today} icon={IconClapperboard} />
          <StatCard label="Shorts created today" value={stats.shorts_created_today} icon={IconScissors} />
          <StatCard label="Queue length" value={stats.queue_length} icon={IconQueue} />
          <StatCard label="Processing now" value={stats.processing_count} icon={IconSettings} />
          <StatCard
            label="Failed jobs"
            value={stats.failed_count}
            icon={IconAlertTriangle}
            tone={stats.failed_count > 0 ? "danger" : "default"}
          />
          <StatCard label="Uploaded today" value={stats.uploaded_today} icon={IconUploadCloud} tone="success" />
          <StatCard
            label="Storage used"
            value={`${bytesToGb(stats.storage_used_bytes)} / ${bytesToGb(stats.storage_quota_bytes)} GB`}
            icon={IconDatabase}
          />
          <StatCard label="YouTube uploads today" value={stats.api_calls_today} icon={IconPlug} />
        </div>
      )}

      <div className="mb-4 flex items-center justify-between">
        <h2 className="text-lg font-semibold tracking-tight">Needs your review</h2>
        <Link href="/queue" className="text-sm font-medium text-brand-400 transition hover:text-brand-300">
          View full queue →
        </Link>
      </div>
      {reviewClips.length === 0 ? (
        <p className="mb-10 text-sm text-gray-500">Nothing waiting for review right now.</p>
      ) : (
        <div className="mb-10 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {reviewClips.map((clip) => (
            <ClipCard key={clip.id} clip={clip} onChange={load} />
          ))}
        </div>
      )}

      <h2 className="mb-4 text-lg font-semibold tracking-tight">Recent jobs</h2>
      <div className="card overflow-x-auto">
        <table className="w-full min-w-[560px] text-left text-sm">
          <thead className="text-xs uppercase tracking-wide text-gray-500">
            <tr>
              <th className="px-4 py-3 font-medium">Type</th>
              <th className="px-4 py-3 font-medium">Status</th>
              <th className="px-4 py-3 font-medium">Progress</th>
              <th className="px-4 py-3 font-medium">Updated</th>
            </tr>
          </thead>
          <tbody>
            {jobs.map((job) => (
              <tr key={job.id} className="border-t border-white/[0.05]">
                <td className="px-4 py-3 capitalize text-gray-200">{job.job_type.replace(/_/g, " ")}</td>
                <td className="px-4 py-3">
                  <span className={`badge ${JOB_STATUS_BADGE[job.status] || "bg-white/5 text-gray-300"}`}>
                    <span className={`h-1.5 w-1.5 rounded-full ${JOB_STATUS_DOT[job.status] || "bg-gray-500"}`} />
                    {job.status}
                  </span>
                </td>
                <td className="px-4 py-3">
                  <div className="flex items-center gap-2">
                    <div className="h-1.5 w-16 overflow-hidden rounded-full bg-white/5">
                      <div
                        className="h-full rounded-full bg-gradient-to-r from-brand-500 to-accent-500"
                        style={{ width: `${Math.round(job.progress * 100)}%` }}
                      />
                    </div>
                    <span className="text-xs text-gray-500">{Math.round(job.progress * 100)}%</span>
                  </div>
                </td>
                <td className="px-4 py-3 text-gray-500">{new Date(job.updated_at).toLocaleTimeString()}</td>
              </tr>
            ))}
            {jobs.length === 0 && (
              <tr>
                <td colSpan={4} className="px-4 py-8 text-center text-gray-500">
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
