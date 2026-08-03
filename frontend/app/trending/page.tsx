"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import AppShell from "@/components/AppShell";
import { IconEye, IconExternalLink, IconPlay, IconUsers, IconX } from "@/components/icons";
import { api } from "@/lib/api";
import type { TrendingClip, WatchedChannel, WatchedChannelDetail } from "@/lib/types";

function formatCompact(n: number): string {
  return new Intl.NumberFormat("en", { notation: "compact", maximumFractionDigits: 1 }).format(n);
}

function formatDuration(seconds: number): string {
  const m = Math.floor(seconds / 60);
  const s = Math.floor(seconds % 60);
  return `${m}:${s.toString().padStart(2, "0")}`;
}

function timeAgo(iso: string | null): string {
  if (!iso) return "";
  const days = Math.floor((Date.now() - new Date(iso).getTime()) / 86_400_000);
  if (days <= 0) return "today";
  if (days === 1) return "1 day ago";
  return `${days} days ago`;
}

function FeedCard({
  clip,
  channel,
  isPlaying,
  onPlay,
  onOpenChannel,
}: {
  clip: TrendingClip;
  channel: WatchedChannel | undefined;
  isPlaying: boolean;
  onPlay: () => void;
  onOpenChannel: () => void;
}) {
  return (
    <div className="relative h-full w-full shrink-0 snap-start bg-black">
      {isPlaying ? (
        <iframe
          src={`https://www.youtube.com/embed/${clip.youtube_video_id}?autoplay=1&mute=1&playsinline=1`}
          title={clip.title}
          allow="autoplay; encrypted-media; picture-in-picture"
          className="absolute inset-0 h-full w-full"
        />
      ) : (
        <button className="absolute inset-0 h-full w-full" onClick={onPlay} aria-label="Play">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={clip.thumbnail_url}
            alt=""
            className="absolute inset-0 h-full w-full object-cover"
          />
          <div className="absolute inset-0 bg-gradient-to-t from-black/90 via-black/10 to-black/40" />
          <div className="absolute inset-0 flex items-center justify-center">
            <div className="flex h-14 w-14 items-center justify-center rounded-full bg-white/15 backdrop-blur-md ring-1 ring-white/30">
              <IconPlay className="h-6 w-6 translate-x-0.5 text-white" />
            </div>
          </div>
        </button>
      )}

      <div className="pointer-events-none absolute inset-x-0 bottom-0 bg-gradient-to-t from-black/85 to-transparent p-4 pt-10">
        <p className="pointer-events-auto line-clamp-2 text-sm font-medium text-white">{clip.title}</p>
        <div className="mt-1.5 flex items-center gap-3 text-xs text-gray-300">
          <span className="inline-flex items-center gap-1">
            <IconEye className="h-3.5 w-3.5" />
            {formatCompact(clip.view_count)}
          </span>
          <span>{formatDuration(clip.duration_seconds)}</span>
          <span>{timeAgo(clip.published_at)}</span>
        </div>
        <button
          onClick={(e) => {
            e.stopPropagation();
            onOpenChannel();
          }}
          className="pointer-events-auto mt-3 flex items-center gap-2 rounded-full bg-white/10 py-1 pl-1 pr-3 backdrop-blur-md transition hover:bg-white/20"
        >
          {channel?.avatar_url ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={channel.avatar_url} alt="" className="h-6 w-6 rounded-full object-cover" />
          ) : (
            <div className="flex h-6 w-6 items-center justify-center rounded-full bg-brand-400/20 text-[10px] text-brand-300">
              {clip.channel_title.slice(0, 1).toUpperCase() || "?"}
            </div>
          )}
          <span className="text-xs font-medium text-white">{clip.channel_title || channel?.label}</span>
        </button>
      </div>
    </div>
  );
}

function ChannelPanel({
  channelId,
  onClose,
}: {
  channelId: string;
  onClose: () => void;
}) {
  const [detail, setDetail] = useState<WatchedChannelDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    setLoading(true);
    api
      .getTrendingChannel(channelId)
      .then(setDetail)
      .catch((e) => setError((e as Error).message))
      .finally(() => setLoading(false));
  }, [channelId]);

  return (
    <div className="fixed inset-0 z-30 flex justify-end">
      <button className="absolute inset-0 bg-black/60 backdrop-blur-sm" onClick={onClose} aria-label="Close" />
      <div className="relative flex h-full w-full max-w-md flex-col overflow-y-auto border-l border-white/10 bg-base-950 p-6">
        <button
          onClick={onClose}
          className="absolute right-5 top-5 rounded-md p-1.5 text-gray-500 transition hover:bg-white/5 hover:text-gray-200"
        >
          <IconX className="h-4 w-4" />
        </button>

        {loading && <p className="text-sm text-gray-500">Loading…</p>}
        {error && <p className="text-sm text-red-400">{error}</p>}

        {detail && (
          <>
            <div className="flex items-center gap-3 pr-8">
              {detail.avatar_url ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={detail.avatar_url} alt="" className="h-14 w-14 rounded-full object-cover" />
              ) : (
                <div className="flex h-14 w-14 items-center justify-center rounded-full bg-brand-400/20 text-lg text-brand-300">
                  {(detail.channel_title || detail.label || "?").slice(0, 1).toUpperCase()}
                </div>
              )}
              <div className="min-w-0">
                <p className="truncate text-base font-medium text-gray-100">
                  {detail.channel_title || detail.label || "Untitled channel"}
                </p>
                {detail.subscriber_count != null && (
                  <p className="text-sm text-gray-400">{formatCompact(detail.subscriber_count)} subscribers</p>
                )}
              </div>
            </div>

            <a
              href={detail.channel_url}
              target="_blank"
              rel="noreferrer"
              className="mt-4 inline-flex items-center gap-1.5 text-sm text-brand-400 hover:text-brand-300"
            >
              <IconExternalLink className="h-3.5 w-3.5" />
              Open channel on YouTube
            </a>

            {detail.last_refreshed_at && (
              <p className="mt-1 text-xs text-gray-600">Updated {timeAgo(detail.last_refreshed_at)}</p>
            )}

            <span className="eyebrow mb-3 mt-6 block">This week&apos;s shorts</span>
            <div className="grid grid-cols-2 gap-3">
              {detail.clips.map((clip) => (
                <a
                  key={clip.id}
                  href={clip.video_url}
                  target="_blank"
                  rel="noreferrer"
                  className="group relative aspect-[9/16] overflow-hidden rounded-lg bg-base-900"
                >
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img
                    src={clip.thumbnail_url}
                    alt=""
                    className="h-full w-full object-cover transition group-hover:scale-105"
                  />
                  <div className="absolute inset-x-0 bottom-0 bg-gradient-to-t from-black/85 to-transparent p-2">
                    <p className="line-clamp-2 text-[11px] text-white">{clip.title}</p>
                    <p className="mt-0.5 text-[10px] text-gray-300">{formatCompact(clip.view_count)} views</p>
                  </div>
                </a>
              ))}
              {detail.clips.length === 0 && (
                <p className="col-span-2 text-sm text-gray-500">No Shorts from this channel this week.</p>
              )}
            </div>
          </>
        )}
      </div>
    </div>
  );
}

export default function TrendingPage() {
  const [clips, setClips] = useState<TrendingClip[]>([]);
  const [channels, setChannels] = useState<WatchedChannel[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [refreshing, setRefreshing] = useState(false);
  const [playingId, setPlayingId] = useState<string | null>(null);
  const [openChannelId, setOpenChannelId] = useState<string | null>(null);

  async function load() {
    try {
      const [c, w] = await Promise.all([api.listTrending(), api.listWatchedChannels()]);
      setClips(c);
      setChannels(w);
      setError("");
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    load();
    const interval = setInterval(load, 10_000);
    return () => clearInterval(interval);
  }, []);

  const channelsById = useMemo(
    () => Object.fromEntries(channels.map((c) => [c.id, c])),
    [channels]
  );

  async function handleRefresh() {
    setRefreshing(true);
    try {
      await api.refreshTrending();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setTimeout(() => setRefreshing(false), 4000);
    }
  }

  return (
    <AppShell>
      <div className="mb-6 flex items-start justify-between gap-4">
        <div>
          <h1 className="mb-1 text-3xl font-extralight tracking-tight">Trending</h1>
          <p className="max-w-lg text-sm text-gray-400">
            The biggest Shorts from your watched channels this week, ranked by views. Playback is
            YouTube&apos;s own embedded player — nothing is downloaded or re-hosted. Tap a channel
            to see more from them.
          </p>
        </div>
        <button className="btn-secondary shrink-0" disabled={refreshing} onClick={handleRefresh}>
          {refreshing ? "Refresh queued…" : "Refresh"}
        </button>
      </div>

      {error && <p className="mb-4 text-sm text-red-400">{error}</p>}

      {!loading && channels.length === 0 && (
        <div className="card p-6 text-sm text-gray-400">
          You haven&apos;t added any channels to watch yet.{" "}
          <Link href="/style" className="text-brand-400 hover:text-brand-300">
            Add some on the Style Analyzer page
          </Link>{" "}
          and their weekly top Shorts will show up here.
        </div>
      )}

      {!loading && channels.length > 0 && clips.length === 0 && (
        <div className="card p-6 text-sm text-gray-400">
          No Shorts from your watched channels this week yet. Try hitting Refresh, or check back
          after the next automatic refresh.
        </div>
      )}

      {clips.length > 0 && (
        <div className="mx-auto flex h-[75vh] w-full max-w-sm flex-col overflow-y-auto rounded-2xl border border-white/10 snap-y snap-mandatory">
          {clips.map((clip) => (
            <FeedCard
              key={clip.id}
              clip={clip}
              channel={channelsById[clip.watched_channel_id]}
              isPlaying={playingId === clip.id}
              onPlay={() => setPlayingId(clip.id)}
              onOpenChannel={() => setOpenChannelId(clip.watched_channel_id)}
            />
          ))}
        </div>
      )}

      {openChannelId && (
        <ChannelPanel channelId={openChannelId} onClose={() => setOpenChannelId(null)} />
      )}
    </AppShell>
  );
}
