"use client";

import { useEffect, useState } from "react";
import AppShell from "@/components/AppShell";
import { api } from "@/lib/api";
import type { ProcessingJob } from "@/lib/types";

const STATUS_STYLES: Record<string, string> = {
  queued: "bg-base-800 text-gray-300",
  running: "bg-amber-950 text-amber-300",
  paused: "bg-base-800 text-gray-400",
  success: "bg-emerald-950 text-emerald-300",
  failed: "bg-red-950 text-red-300",
  cancelled: "bg-base-800 text-gray-500",
};

export default function QueuePage() {
  const [jobs, setJobs] = useState<ProcessingJob[]>([]);
  const [filter, setFilter] = useState<string>("");
  const [busyId, setBusyId] = useState<string | null>(null);

  async function load() {
    setJobs(await api.listJobs(filter || undefined));
  }

  useEffect(() => {
    load();
    const interval = setInterval(load, 3000);
    return () => clearInterval(interval);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [filter]);

  async function act(id: string, fn: (id: string) => Promise<unknown>) {
    setBusyId(id);
    try {
      await fn(id);
      await load();
    } finally {
      setBusyId(null);
    }
  }

  return (
    <AppShell>
      <div className="mb-6 flex items-center justify-between">
        <h1 className="text-2xl font-semibold">Processing queue</h1>
        <select
          className="input w-48"
          value={filter}
          onChange={(e) => setFilter(e.target.value)}
        >
          <option value="">All statuses</option>
          <option value="queued">Queued</option>
          <option value="running">Running</option>
          <option value="paused">Paused</option>
          <option value="success">Success</option>
          <option value="failed">Failed</option>
          <option value="cancelled">Cancelled</option>
        </select>
      </div>

      <div className="card overflow-hidden">
        <table className="w-full text-left text-sm">
          <thead className="bg-base-800 text-gray-400">
            <tr>
              <th className="px-4 py-2 font-medium">Type</th>
              <th className="px-4 py-2 font-medium">Status</th>
              <th className="px-4 py-2 font-medium">Progress</th>
              <th className="px-4 py-2 font-medium">Attempts</th>
              <th className="px-4 py-2 font-medium">Error</th>
              <th className="px-4 py-2 font-medium">Actions</th>
            </tr>
          </thead>
          <tbody>
            {jobs.map((job) => (
              <tr key={job.id} className="border-t border-base-800 align-top">
                <td className="px-4 py-2">{job.job_type}</td>
                <td className="px-4 py-2">
                  <span className={`badge ${STATUS_STYLES[job.status] || "bg-base-800"}`}>{job.status}</span>
                </td>
                <td className="px-4 py-2">
                  <div className="h-1.5 w-24 overflow-hidden rounded-full bg-base-800">
                    <div
                      className="h-full bg-brand-500"
                      style={{ width: `${Math.round(job.progress * 100)}%` }}
                    />
                  </div>
                </td>
                <td className="px-4 py-2 text-gray-500">{job.attempts}</td>
                <td className="max-w-xs truncate px-4 py-2 text-red-400">{job.error_message}</td>
                <td className="space-x-2 px-4 py-2">
                  {job.status === "running" && (
                    <button
                      disabled={busyId === job.id}
                      className="btn-secondary px-2 py-1 text-xs"
                      onClick={() => act(job.id, api.pauseJob)}
                    >
                      Pause
                    </button>
                  )}
                  {(job.status === "queued" || job.status === "running" || job.status === "paused") && (
                    <button
                      disabled={busyId === job.id}
                      className="btn-danger px-2 py-1 text-xs"
                      onClick={() => act(job.id, api.cancelJob)}
                    >
                      Cancel
                    </button>
                  )}
                  {job.status === "failed" && (
                    <button
                      disabled={busyId === job.id}
                      className="btn-primary px-2 py-1 text-xs"
                      onClick={() => act(job.id, api.retryJob)}
                    >
                      Retry
                    </button>
                  )}
                </td>
              </tr>
            ))}
            {jobs.length === 0 && (
              <tr>
                <td colSpan={6} className="px-4 py-6 text-center text-gray-500">
                  Queue is empty.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </AppShell>
  );
}
