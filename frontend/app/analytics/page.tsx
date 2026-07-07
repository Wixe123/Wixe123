"use client";

import { useEffect, useMemo, useState } from "react";
import AppShell from "@/components/AppShell";
import { IconClock, IconEye, IconHeart, IconSparkles, IconUsers } from "@/components/icons";
import { api } from "@/lib/api";
import type { AnalyticsOverview, ClipPerformance } from "@/lib/types";

const RANGES = [
  { label: "7 days", days: 7 },
  { label: "28 days", days: 28 },
  { label: "90 days", days: 90 },
];

function Delta({ pct }: { pct: number | null }) {
  if (pct === null) return null;
  const up = pct >= 0;
  return (
    <span className={`ml-2 text-xs font-medium ${up ? "text-emerald-400" : "text-red-400"}`}>
      {up ? "+" : ""}
      {pct.toFixed(1)}%
    </span>
  );
}

export default function AnalyticsPage() {
  const [days, setDays] = useState(28);
  const [overview, setOverview] = useState<AnalyticsOverview | null>(null);
  const [clips, setClips] = useState<ClipPerformance[]>([]);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(true);
  const [connected, setConnected] = useState<boolean | null>(null);

  async function load() {
    setError("");
    try {
      const status = await api.youtubeStatus();
      setConnected(status.connected);
      if (!status.connected) {
        setLoading(false);
        return;
      }
      const [o, c] = await Promise.all([api.analyticsOverview(days), api.analyticsClips(days)]);
      setOverview(o);
      setClips(c);
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    setLoading(true);
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [days]);

  const insight = useMemo(() => {
    const withViews = clips.filter((c) => c.views > 0);
    if (withViews.length < 2) return null;
    const sorted = [...withViews].sort((a, b) => b.views - a.views);
    const cutoff = Math.max(1, Math.floor(sorted.length / 2));
    const top = sorted.slice(0, cutoff);
    const rest = sorted.slice(cutoff);

    const avgViewsByReason: Record<string, { total: number; count: number }> = {};
    for (const clip of withViews) {
      for (const reason of clip.score_reasons) {
        avgViewsByReason[reason] ||= { total: 0, count: 0 };
        avgViewsByReason[reason].total += clip.views;
        avgViewsByReason[reason].count += 1;
      }
    }
    const ranked = Object.entries(avgViewsByReason)
      .map(([reason, { total, count }]) => ({ reason, avg: total / count }))
      .sort((a, b) => b.avg - a.avg);

    const topAvg = top.reduce((s, c) => s + c.views, 0) / top.length;
    const restAvg = rest.length ? rest.reduce((s, c) => s + c.views, 0) / rest.length : 0;

    return { ranked: ranked.slice(0, 3), topAvg, restAvg };
  }, [clips]);

  return (
    <AppShell>
      <div className="mb-8 flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <p className="eyebrow mb-2">Live from YouTube</p>
          <h1 className="text-3xl font-extralight tracking-tight">Analytics</h1>
        </div>
        <div className="flex gap-1 self-start rounded-md border border-white/10 p-1 sm:self-auto">
          {RANGES.map((r) => (
            <button
              key={r.days}
              onClick={() => setDays(r.days)}
              className={`rounded px-3 py-1.5 text-xs font-medium transition ${
                days === r.days ? "bg-brand-400/15 text-brand-300" : "text-gray-500 hover:text-gray-200"
              }`}
            >
              {r.label}
            </button>
          ))}
        </div>
      </div>

      {loading && <p className="text-sm text-gray-500">Loading…</p>}

      {!loading && connected === false && (
        <div className="card p-8 text-center">
          <p className="mb-4 text-sm text-gray-400">
            Connect your YouTube channel to see live views, watch time, and per-clip performance here.
          </p>
          <a href="/settings" className="btn-primary inline-flex">
            Go to Settings
          </a>
        </div>
      )}

      {error && <p className="mb-4 text-sm text-red-400">{error}</p>}

      {!loading && connected && overview && (
        <>
          <div className="mb-10 grid grid-cols-2 gap-4 md:grid-cols-4">
            <div className="card px-5 py-4">
              <div className="flex items-center justify-between">
                <span className="text-[11px] font-medium uppercase tracking-wider2 text-gray-500">Views</span>
                <IconEye className="h-4 w-4 text-gray-600" strokeWidth={1.3} />
              </div>
              <p className="mt-3 flex items-baseline text-3xl font-extralight tracking-tight text-gray-50">
                {overview.views.toLocaleString()}
                <Delta pct={overview.views_delta_pct} />
              </p>
            </div>
            <div className="card px-5 py-4">
              <div className="flex items-center justify-between">
                <span className="text-[11px] font-medium uppercase tracking-wider2 text-gray-500">Watch time</span>
                <IconClock className="h-4 w-4 text-gray-600" strokeWidth={1.3} />
              </div>
              <p className="mt-3 flex items-baseline text-3xl font-extralight tracking-tight text-gray-50">
                {(overview.watch_time_minutes / 60).toFixed(1)}h
                <Delta pct={overview.watch_time_delta_pct} />
              </p>
            </div>
            <div className="card px-5 py-4">
              <div className="flex items-center justify-between">
                <span className="text-[11px] font-medium uppercase tracking-wider2 text-gray-500">Subscribers gained</span>
                <IconUsers className="h-4 w-4 text-gray-600" strokeWidth={1.3} />
              </div>
              <p className="mt-3 flex items-baseline text-3xl font-extralight tracking-tight text-gray-50">
                {overview.subscribers_gained.toLocaleString()}
                <Delta pct={overview.subscribers_delta_pct} />
              </p>
            </div>
            <div className="card px-5 py-4">
              <div className="flex items-center justify-between">
                <span className="text-[11px] font-medium uppercase tracking-wider2 text-gray-500">Likes</span>
                <IconHeart className="h-4 w-4 text-gray-600" strokeWidth={1.3} />
              </div>
              <p className="mt-3 text-3xl font-extralight tracking-tight text-gray-50">
                {overview.likes.toLocaleString()}
              </p>
            </div>
          </div>

          {insight && insight.ranked.length > 0 && (
            <div className="card mb-10 p-6">
              <div className="mb-3 flex items-center gap-2">
                <IconSparkles className="h-4 w-4 text-brand-400" />
                <span className="eyebrow">What to lean into</span>
              </div>
              <p className="mb-4 text-sm font-light leading-relaxed text-gray-300">
                Your top half of clips by views averaged{" "}
                <span className="text-gray-100">{Math.round(insight.topAvg).toLocaleString()}</span> views vs{" "}
                <span className="text-gray-100">{Math.round(insight.restAvg).toLocaleString()}</span> for the rest.
                These hook types correlate with the highest average views:
              </p>
              <div className="flex flex-wrap gap-2">
                {insight.ranked.map((r) => (
                  <span key={r.reason} className="badge bg-brand-400/10 text-brand-300">
                    {r.reason} · {Math.round(r.avg).toLocaleString()} avg views
                  </span>
                ))}
              </div>
            </div>
          )}

          <p className="eyebrow mb-5">Clips uploaded via ShortsForge</p>
          <div className="card overflow-x-auto">
            <table className="w-full min-w-[760px] text-left text-sm">
              <thead className="text-xs uppercase tracking-wide text-gray-500">
                <tr>
                  <th className="px-4 py-3 font-medium">Title</th>
                  <th className="px-4 py-3 font-medium">Views</th>
                  <th className="px-4 py-3 font-medium">Watch time</th>
                  <th className="px-4 py-3 font-medium">Avg % viewed</th>
                  <th className="px-4 py-3 font-medium">Likes</th>
                  <th className="px-4 py-3 font-medium">Comments</th>
                  <th className="px-4 py-3 font-medium">AI score</th>
                </tr>
              </thead>
              <tbody>
                {clips.map((c) => (
                  <tr key={c.clip_id} className="border-t border-white/[0.05]">
                    <td className="max-w-xs truncate px-4 py-3 text-gray-100">
                      <a
                        href={`https://youtube.com/watch?v=${c.youtube_video_id}`}
                        target="_blank"
                        rel="noreferrer"
                        className="hover:text-brand-300"
                      >
                        {c.title || "Untitled"}
                      </a>
                    </td>
                    <td className="px-4 py-3 text-gray-200">{c.views.toLocaleString()}</td>
                    <td className="px-4 py-3 text-gray-500">{(c.watch_time_minutes / 60).toFixed(1)}h</td>
                    <td className="px-4 py-3 text-gray-500">{c.average_view_percentage.toFixed(0)}%</td>
                    <td className="px-4 py-3 text-gray-500">{c.likes.toLocaleString()}</td>
                    <td className="px-4 py-3 text-gray-500">{c.comments.toLocaleString()}</td>
                    <td className="px-4 py-3 text-brand-400">{c.score.toFixed(1)}</td>
                  </tr>
                ))}
                {clips.length === 0 && (
                  <tr>
                    <td colSpan={7} className="px-4 py-8 text-center text-gray-500">
                      No uploaded clips with data yet.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </>
      )}
    </AppShell>
  );
}
