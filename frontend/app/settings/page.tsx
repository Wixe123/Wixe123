"use client";

import { useEffect, useState } from "react";
import AppShell from "@/components/AppShell";
import { api } from "@/lib/api";
import type { BrandingPreset, UserSettings } from "@/lib/types";

export default function SettingsPage() {
  const [settings, setSettings] = useState<UserSettings | null>(null);
  const [presets, setPresets] = useState<BrandingPreset[]>([]);
  const [youtube, setYoutube] = useState<{ connected: boolean; channel_title?: string } | null>(null);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  const [loadError, setLoadError] = useState("");

  async function load() {
    try {
      const [s, p, y] = await Promise.all([
        api.getSettings(),
        api.listBrandingPresets(),
        api.youtubeStatus(),
      ]);
      setSettings(s);
      setPresets(p);
      setYoutube(y);
      setLoadError("");
    } catch (e) {
      setLoadError((e as Error).message);
    }
  }

  useEffect(() => {
    load();
  }, []);

  async function save(patch: Partial<UserSettings>) {
    if (!settings) return;
    setSaving(true);
    setSaved(false);
    try {
      const updated = await api.updateSettings(patch);
      setSettings(updated);
      setSaved(true);
      setTimeout(() => setSaved(false), 1500);
    } finally {
      setSaving(false);
    }
  }

  async function connectYoutube() {
    const { auth_url } = await api.youtubeConnectUrl();
    window.location.href = auth_url;
  }

  if (!settings) {
    return (
      <AppShell>
        {loadError ? (
          <p className="text-sm text-red-400">{loadError}</p>
        ) : (
          <p className="text-gray-500">Loading settings…</p>
        )}
      </AppShell>
    );
  }

  return (
    <AppShell>
      <h1 className="mb-6 text-3xl font-extralight tracking-tight">Settings</h1>

      <section className="card mb-6 p-6">
        <h2 className="mb-4 text-base font-light tracking-tight">YouTube channel</h2>
        {youtube?.connected ? (
          <div className="flex items-center justify-between">
            <p className="text-sm text-emerald-400">Connected: {youtube.channel_title}</p>
            <button className="btn-secondary" onClick={connectYoutube}>
              Reconnect
            </button>
          </div>
        ) : (
          <div className="flex items-center justify-between">
            <p className="text-sm text-gray-400">Connect your channel to enable one-click uploads and live analytics.</p>
            <button className="btn-primary" onClick={connectYoutube}>
              Connect YouTube
            </button>
          </div>
        )}
        {youtube?.connected && (
          <p className="mt-3 text-xs text-gray-600">
            Connected before analytics support was added? Hit Reconnect to grant the new permission — otherwise the
            Analytics page will show a permission error.
          </p>
        )}
      </section>

      <section className="card mb-6 p-6">
        <h2 className="mb-4 text-base font-light tracking-tight">Subtitles</h2>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <label className="text-sm text-gray-400">
            Font
            <input
              className="input mt-1"
              defaultValue={settings.subtitle_font}
              onBlur={(e) => save({ subtitle_font: e.target.value })}
            />
          </label>
          <label className="text-sm text-gray-400">
            Position
            <select
              className="input mt-1"
              defaultValue={settings.subtitle_position}
              onChange={(e) => save({ subtitle_position: e.target.value })}
            >
              <option value="bottom">Bottom</option>
              <option value="center">Center</option>
              <option value="top">Top</option>
            </select>
          </label>
          <label className="text-sm text-gray-400">
            Text color
            <input
              type="color"
              className="input mt-1 h-10"
              defaultValue={settings.subtitle_color}
              onBlur={(e) => save({ subtitle_color: e.target.value })}
            />
          </label>
          <label className="text-sm text-gray-400">
            Highlight color
            <input
              type="color"
              className="input mt-1 h-10"
              defaultValue={settings.subtitle_highlight_color}
              onBlur={(e) => save({ subtitle_highlight_color: e.target.value })}
            />
          </label>
          <label className="flex items-center gap-2 text-sm text-gray-400">
            <input
              type="checkbox"
              defaultChecked={settings.subtitle_emoji_enabled}
              onChange={(e) => save({ subtitle_emoji_enabled: e.target.checked })}
            />
            Auto-add emoji
          </label>
          <label className="text-sm text-gray-400">
            Language
            <input
              className="input mt-1"
              defaultValue={settings.subtitle_language}
              onBlur={(e) => save({ subtitle_language: e.target.value })}
            />
          </label>
        </div>
      </section>

      <section className="card mb-6 p-6">
        <h2 className="mb-4 text-base font-light tracking-tight">Clip generation</h2>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <label className="text-sm text-gray-400">
            Min clip length (s)
            <input
              type="number"
              className="input mt-1"
              defaultValue={settings.clip_min_seconds}
              onBlur={(e) => save({ clip_min_seconds: Number(e.target.value) })}
            />
          </label>
          <label className="text-sm text-gray-400">
            Max clip length (s)
            <input
              type="number"
              className="input mt-1"
              defaultValue={settings.clip_max_seconds}
              onBlur={(e) => save({ clip_max_seconds: Number(e.target.value) })}
            />
          </label>
          <label className="text-sm text-gray-400">
            Max clips per video
            <input
              type="number"
              className="input mt-1"
              defaultValue={settings.max_clips_per_video}
              onBlur={(e) => save({ max_clips_per_video: Number(e.target.value) })}
            />
          </label>
          <label className="text-sm text-gray-400">
            AI sensitivity ({settings.ai_sensitivity.toFixed(2)})
            <input
              type="range"
              min={0}
              max={1}
              step={0.05}
              className="mt-3 w-full"
              defaultValue={settings.ai_sensitivity}
              onChange={(e) => save({ ai_sensitivity: Number(e.target.value) })}
            />
            <span className="text-xs text-gray-500">Lower = more (looser) clips, higher = fewer, stricter clips</span>
          </label>
          <label className="text-sm text-gray-400">
            Export quality
            <select
              className="input mt-1"
              defaultValue={settings.export_quality}
              onChange={(e) => save({ export_quality: e.target.value })}
            >
              <option value="720p">720p</option>
              <option value="1080p">1080p</option>
              <option value="4k">4K</option>
            </select>
          </label>
        </div>
      </section>

      <section className="card mb-6 p-6">
        <h2 className="mb-4 text-base font-light tracking-tight">Upload defaults</h2>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <label className="text-sm text-gray-400">
            Default visibility
            <select
              className="input mt-1"
              defaultValue={settings.default_visibility}
              onChange={(e) => save({ default_visibility: e.target.value as UserSettings["default_visibility"] })}
            >
              <option value="private">Private</option>
              <option value="unlisted">Unlisted</option>
              <option value="public">Public</option>
              <option value="draft">Draft</option>
            </select>
          </label>
          <label className="text-sm text-gray-400">
            Default branding preset
            <select
              className="input mt-1"
              defaultValue={settings.default_branding_preset_id ?? ""}
              onChange={(e) => save({ default_branding_preset_id: e.target.value || null })}
            >
              <option value="">None</option>
              {presets.map((p) => (
                <option key={p.id} value={p.id}>
                  {p.name}
                </option>
              ))}
            </select>
          </label>
          <label className="flex items-center gap-2 text-sm text-gray-400">
            <input
              type="checkbox"
              defaultChecked={settings.auto_upload_after_approval}
              onChange={(e) => save({ auto_upload_after_approval: e.target.checked })}
            />
            Auto-upload immediately after I approve a clip
          </label>
        </div>
      </section>

      <section className="card mb-6 p-6">
        <h2 className="mb-1 text-base font-light tracking-tight">Automation</h2>
        <p className="mb-4 text-xs text-gray-500">
          Run the whole pipeline hands-off: pull in new videos from your channel automatically,
          and skip manual review for clips that already score well.
        </p>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <div>
            <label className="flex items-center gap-2 text-sm text-gray-400">
              <input
                type="checkbox"
                disabled={!youtube?.connected}
                defaultChecked={settings.auto_import_from_channel}
                onChange={(e) => save({ auto_import_from_channel: e.target.checked })}
              />
              Auto-import new uploads from my channel
            </label>
            {!youtube?.connected && (
              <p className="mt-1 text-xs text-gray-600">Connect your YouTube channel above first.</p>
            )}
          </div>
          <div>
            <label className="flex items-center gap-2 text-sm text-gray-400">
              <input
                type="checkbox"
                checked={settings.auto_approve_score_threshold !== null}
                onChange={(e) => save({ auto_approve_score_threshold: e.target.checked ? 7 : null })}
              />
              Auto-upload clips above a score threshold
            </label>
            {settings.auto_approve_score_threshold !== null && (
              <label className="mt-2 block text-sm text-gray-400">
                Score threshold ({settings.auto_approve_score_threshold.toFixed(1)})
                <input
                  type="range"
                  min={0}
                  max={12}
                  step={0.5}
                  className="mt-2 w-full"
                  defaultValue={settings.auto_approve_score_threshold}
                  onChange={(e) => save({ auto_approve_score_threshold: Number(e.target.value) })}
                />
                <span className="text-xs text-gray-500">Clips scoring at or above this skip review and upload immediately; scores typically range 0-10.</span>
              </label>
            )}
          </div>
          <div>
            <label className="flex items-center gap-2 text-sm text-gray-400">
              <input
                type="checkbox"
                checked={settings.posting_cadence_per_day !== null}
                onChange={(e) => save({ posting_cadence_per_day: e.target.checked ? 2 : null })}
              />
              Spread posts out instead of publishing a whole batch at once
            </label>
            {settings.posting_cadence_per_day !== null && (
              <label className="mt-2 block text-sm text-gray-400">
                Shorts per day ({settings.posting_cadence_per_day})
                <input
                  type="range"
                  min={1}
                  max={12}
                  step={1}
                  className="mt-2 w-full"
                  defaultValue={settings.posting_cadence_per_day}
                  onChange={(e) => save({ posting_cadence_per_day: Number(e.target.value) })}
                />
                <span className="text-xs text-gray-500">
                  If you upload a backlog of videos at once, approved clips get scheduled at this pace instead of
                  all going public immediately. Clips still upload right away — YouTube just holds each one
                  private until its scheduled time.
                </span>
              </label>
            )}
          </div>
        </div>
      </section>

      <p className="text-xs text-gray-500">
        {saving ? "Saving…" : saved ? "Saved." : ""}
      </p>
    </AppShell>
  );
}
