"use client";

import { useEffect, useState } from "react";
import AppShell from "@/components/AppShell";
import { IconExternalLink } from "@/components/icons";
import { api } from "@/lib/api";
import type { StyleProfile } from "@/lib/types";

const STATUS_STYLES: Record<string, string> = {
  analyzing: "bg-amber-500/15 text-amber-300",
  ready: "bg-emerald-500/15 text-emerald-300",
  failed: "bg-red-500/15 text-red-300",
};

function StyleProfileCard({
  profile,
  isActive,
  busy,
  onApply,
  onClear,
}: {
  profile: StyleProfile;
  isActive: boolean;
  busy: boolean;
  onApply: (id: string) => void;
  onClear: () => void;
}) {
  const [expanded, setExpanded] = useState(false);
  const hasFindings = profile.status === "ready";

  return (
    <div className={`card p-5 ${isActive ? "ring-1 ring-brand-400/50" : ""}`}>
      <div className="mb-2 flex items-start justify-between gap-3">
        <div className="min-w-0">
          <p className="truncate text-sm font-medium text-gray-100">
            {profile.creator_label || "Untitled reference"}
          </p>
          <a
            href={profile.source_url}
            target="_blank"
            rel="noreferrer"
            className="mt-0.5 inline-flex items-center gap-1 truncate text-xs text-gray-500 hover:text-brand-400"
          >
            <IconExternalLink className="h-3 w-3 shrink-0" />
            <span className="truncate">{profile.source_url}</span>
          </a>
        </div>
        <span className={`badge shrink-0 ${STATUS_STYLES[profile.status] || "bg-white/5"}`}>
          {profile.status}
        </span>
      </div>

      {profile.status === "failed" && (
        <p className="mt-2 text-sm text-red-400">{profile.error_message || "Analysis failed."}</p>
      )}

      {hasFindings && (
        <>
          <button
            onClick={() => setExpanded((v) => !v)}
            className="mt-3 text-xs font-medium text-brand-400 transition hover:text-brand-300"
          >
            {expanded ? "Hide findings" : "Show findings"}
          </button>
          {expanded && (
            <div className="mt-3 space-y-3 text-sm">
              {profile.summary && (
                <p className="whitespace-pre-line text-gray-200">{profile.summary}</p>
              )}
              <div>
                <span className="eyebrow">Hook</span>
                <p className="mt-1 text-gray-400">{profile.hook_analysis}</p>
              </div>
              <div>
                <span className="eyebrow">Pacing</span>
                <p className="mt-1 text-gray-400">{profile.pacing_analysis}</p>
              </div>
              <div>
                <span className="eyebrow">Structure</span>
                <p className="mt-1 text-gray-400">{profile.structure_analysis}</p>
              </div>
            </div>
          )}

          {isActive ? (
            <div className="mt-4 flex items-center justify-between gap-2">
              <span className="text-xs font-medium text-brand-300">Applied to new clips</span>
              <button disabled={busy} className="btn-secondary px-2.5 py-1 text-xs" onClick={onClear}>
                Remove
              </button>
            </div>
          ) : (
            <button
              disabled={busy}
              className="btn-primary mt-4 w-full"
              onClick={() => onApply(profile.id)}
            >
              Apply this style
            </button>
          )}
        </>
      )}
    </div>
  );
}

export default function StylePage() {
  const [profiles, setProfiles] = useState<StyleProfile[]>([]);
  const [activeId, setActiveId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [url, setUrl] = useState("");
  const [label, setLabel] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [applying, setApplying] = useState(false);

  async function load() {
    try {
      const [p, settings] = await Promise.all([api.listStyleProfiles(), api.getSettings()]);
      setProfiles(p);
      setActiveId(settings.active_style_profile_id);
      setError("");
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    load();
    const interval = setInterval(load, 4000);
    return () => clearInterval(interval);
  }, []);

  async function handleAnalyze() {
    if (!url.trim()) return;
    setSubmitting(true);
    setError("");
    try {
      await api.createStyleProfile(url.trim(), label.trim());
      setUrl("");
      setLabel("");
      await load();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setSubmitting(false);
    }
  }

  async function applyStyle(id: string) {
    setApplying(true);
    try {
      await api.updateSettings({ active_style_profile_id: id });
      await load();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setApplying(false);
    }
  }

  async function clearStyle() {
    setApplying(true);
    try {
      await api.updateSettings({ active_style_profile_id: null });
      await load();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setApplying(false);
    }
  }

  return (
    <AppShell>
      <h1 className="mb-1 text-3xl font-extralight tracking-tight">Style analyzer</h1>
      <p className="mb-6 text-sm text-gray-400">
        Paste a reference video from any creator you want to learn from — this analyzes their
        hook, pacing, and structure so you can deliberately apply the same approach to your own
        content. It doesn&apos;t download or reuse their video itself, only a written breakdown of
        their technique. Apply one to a card below and every clip title/description you generate
        from now on is written in that style.
      </p>

      <div className="card mb-8 p-6">
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <label className="text-sm text-gray-400">
            Reference video URL
            <input
              className="input mt-1"
              placeholder="https://www.youtube.com/watch?v=..."
              value={url}
              onChange={(e) => setUrl(e.target.value)}
            />
          </label>
          <label className="text-sm text-gray-400">
            Creator label (optional)
            <input
              className="input mt-1"
              placeholder="e.g. their channel name"
              value={label}
              onChange={(e) => setLabel(e.target.value)}
            />
          </label>
        </div>
        <button className="btn-primary mt-4" disabled={submitting || !url.trim()} onClick={handleAnalyze}>
          {submitting ? "Starting…" : "Analyze"}
        </button>
      </div>

      {error && <p className="mb-4 text-sm text-red-400">{error}</p>}

      <span className="eyebrow mb-5 block">Past analyses</span>
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {profiles.map((p) => (
          <StyleProfileCard
            key={p.id}
            profile={p}
            isActive={p.id === activeId}
            busy={applying}
            onApply={applyStyle}
            onClear={clearStyle}
          />
        ))}
        {profiles.length === 0 && (
          <p className="text-sm text-gray-500">
            {loading ? "Loading…" : "No analyses yet — paste a reference video above to get started."}
          </p>
        )}
      </div>
    </AppShell>
  );
}
