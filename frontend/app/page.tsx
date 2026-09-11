"use client";

import { AnimatePresence, motion } from "framer-motion";
import { useEffect, useRef, useState } from "react";
import AppShell from "@/components/AppShell";
import ClipCard from "@/components/ClipCard";
import { IconAlertTriangle, IconCheck } from "@/components/icons";
import { api } from "@/lib/api";
import type { Clip, JobType, ProcessingJob, UserSettings } from "@/lib/types";

interface Stage {
  type: JobType;
  name: string;
  role: string;
}

const STAGES: Stage[] = [
  {
    type: "analyze_video",
    name: "Analyzer",
    role: "Watches new footage and finds the clip-worthy moments.",
  },
  {
    type: "generate_faceless_video",
    name: "Scriptwriter",
    role: "Writes and builds faceless explainer Shorts from scratch.",
  },
  {
    type: "render_clip",
    name: "Editor",
    role: "Cuts, captions, and renders the approved clips.",
  },
  {
    type: "upload_clip",
    name: "Publisher",
    role: "Uploads finished Shorts to YouTube, on schedule.",
  },
];

function truncate(text: string, max: number): string {
  if (text.length <= max) return text;
  return text.slice(0, max - 1).trimEnd() + "…";
}

interface Bucket {
  running: ProcessingJob | null;
  queuedCount: number;
  justFinished: boolean;
  failed: ProcessingJob | null;
}

export default function ChannelPage() {
  const [settings, setSettings] = useState<UserSettings | null>(null);
  const [youtube, setYoutube] = useState<{ connected: boolean; channel_title?: string } | null>(null);
  const [settingsError, setSettingsError] = useState("");
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  const [generatingFaceless, setGeneratingFaceless] = useState(false);
  const [facelessMessage, setFacelessMessage] = useState("");

  const [reviewClips, setReviewClips] = useState<Clip[]>([]);
  const [jobs, setJobs] = useState<ProcessingJob[]>([]);
  const [pipelineError, setPipelineError] = useState("");
  const [flash, setFlash] = useState<Record<string, boolean>>({});
  const prevSuccessIds = useRef<Set<string>>(new Set());

  async function loadSettings() {
    try {
      const [s, y] = await Promise.all([api.getSettings(), api.youtubeStatus()]);
      setSettings(s);
      setYoutube(y);
      setSettingsError("");
    } catch (e) {
      setSettingsError((e as Error).message);
    }
  }

  async function loadPipeline() {
    try {
      const [clips, jobList] = await Promise.all([api.listClips("ready_for_review"), api.listJobs()]);

      const newlyDone: Record<string, boolean> = {};
      for (const j of jobList) {
        if (j.status === "success" && !prevSuccessIds.current.has(j.id)) {
          newlyDone[j.job_type] = true;
        }
      }
      if (Object.keys(newlyDone).length) {
        setFlash((f) => ({ ...f, ...newlyDone }));
        setTimeout(() => {
          setFlash((f) => {
            const next = { ...f };
            for (const k of Object.keys(newlyDone)) delete next[k];
            return next;
          });
        }, 2200);
      }
      prevSuccessIds.current = new Set(jobList.filter((j) => j.status === "success").map((j) => j.id));

      setReviewClips(clips);
      setJobs(jobList);
      setPipelineError("");
    } catch (e) {
      setPipelineError((e as Error).message);
    }
  }

  useEffect(() => {
    loadSettings();
  }, []);

  useEffect(() => {
    loadPipeline();
    const interval = setInterval(loadPipeline, 3000);
    return () => clearInterval(interval);
    // eslint-disable-next-line react-hooks/exhaustive-deps
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

  async function generateFaceless() {
    setGeneratingFaceless(true);
    setFacelessMessage("");
    try {
      await api.generateFacelessVideo();
      setFacelessMessage("Queued — watch the agents below for progress.");
    } catch (e) {
      setFacelessMessage((e as Error).message);
    } finally {
      setGeneratingFaceless(false);
    }
  }

  function bucketFor(type: JobType): Bucket {
    const forType = jobs.filter((j) => j.job_type === type);
    return {
      running: forType.find((j) => j.status === "running") || null,
      queuedCount: forType.filter((j) => j.status === "queued").length,
      justFinished: !!flash[type],
      failed: forType.find((j) => j.status === "failed") || null,
    };
  }

  const anyActive = STAGES.some((s) => bucketFor(s.type).running);

  return (
    <AppShell>
      <div className="mb-6">
        <h1 className="text-3xl font-extralight tracking-tight">My faceless channel</h1>
        <p className="mt-1 text-sm text-gray-500">Set it up once — the agents below keep it running.</p>
      </div>

      {settingsError && <p className="mb-4 text-sm text-red-400">{settingsError}</p>}

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
            <p className="text-sm text-gray-400">Connect your channel to enable uploads and scheduling.</p>
            <button className="btn-primary" onClick={connectYoutube}>
              Connect YouTube
            </button>
          </div>
        )}
      </section>

      <section className="card mb-6 p-6">
        <h2 className="mb-1 text-base font-light tracking-tight">Channel setup</h2>
        <p className="mb-4 text-xs text-gray-500">
          Pick a niche and the agents write a from-scratch Vox-style explainer Short — topic, narration,
          charts/photos/callouts — no footage of your own required.
        </p>
        {!settings ? (
          <p className="text-sm text-gray-500">Loading…</p>
        ) : (
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <label className="text-sm text-gray-400 sm:col-span-2">
              Channel niche
              <input
                className="input mt-1"
                placeholder="e.g. space exploration, ancient history, personal finance"
                defaultValue={settings.faceless_niche ?? ""}
                onBlur={(e) => save({ faceless_niche: e.target.value || null })}
              />
              <span className="text-xs text-gray-500">Required before a video can be generated.</span>
            </label>

            <label className="flex items-center gap-2 text-sm text-gray-400">
              <input
                type="checkbox"
                defaultChecked={settings.faceless_auto_upload}
                onChange={(e) => save({ faceless_auto_upload: e.target.checked })}
              />
              Auto-upload generated videos instead of holding them for review
            </label>

            <div>
              <label className="flex items-center gap-2 text-sm text-gray-400">
                <input
                  type="checkbox"
                  checked={settings.posting_cadence_per_day !== null}
                  onChange={(e) => save({ posting_cadence_per_day: e.target.checked ? 2 : null })}
                />
                Spread uploads out instead of posting a whole batch at once
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
                </label>
              )}
            </div>

            <div className="sm:col-span-2">
              <button
                className="btn-primary"
                disabled={!settings.faceless_niche || generatingFaceless}
                onClick={generateFaceless}
              >
                {generatingFaceless ? "Queuing…" : "Generate one now"}
              </button>
              {facelessMessage && <p className="mt-2 text-xs text-gray-500">{facelessMessage}</p>}
              <p className="mt-2 text-xs text-gray-500">{saving ? "Saving…" : saved ? "Saved." : ""}</p>
            </div>
          </div>
        )}
      </section>

      {pipelineError && <p className="mb-4 text-sm text-red-400">{pipelineError}</p>}

      {reviewClips.length > 0 && (
        <div className="mb-10">
          <span className="eyebrow mb-4 block">Needs your review</span>
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {reviewClips.map((clip) => (
              <ClipCard key={clip.id} clip={clip} onChange={loadPipeline} />
            ))}
          </div>
        </div>
      )}

      <span className="eyebrow mb-4 block">Agent world</span>
      <div className="card relative overflow-hidden p-8 md:p-16">
        <div
          className="pointer-events-none absolute inset-0"
          style={{
            background: "radial-gradient(60rem 30rem at 50% -10%, rgba(204,166,96,0.10), transparent 60%)",
          }}
        />

        {/* connecting current, only animated while something's moving through the pipeline */}
        <div className="pointer-events-none absolute inset-x-16 top-1/2 hidden -translate-y-1/2 md:block">
          <div className="h-px w-full bg-white/[0.06]" />
          {anyActive && (
            <motion.div
              className="absolute top-1/2 h-1.5 w-1.5 -translate-y-1/2 rounded-full bg-brand-400 shadow-[0_0_8px_2px_rgba(204,166,96,0.6)]"
              animate={{ left: ["0%", "100%"] }}
              transition={{ duration: 3.2, repeat: Infinity, ease: "linear" }}
            />
          )}
        </div>

        <div className="relative grid grid-cols-2 gap-y-10 md:grid-cols-4 md:gap-y-0">
          {STAGES.map((stage) => (
            <AgentStation key={stage.type} stage={stage} bucket={bucketFor(stage.type)} />
          ))}
        </div>
      </div>

      <p className="mt-4 text-center text-xs text-gray-600">
        Each agent lights up while a real job of its kind is running — this is your Celery queue, watchable.
      </p>
    </AppShell>
  );
}

function AgentStation({ stage, bucket }: { stage: Stage; bucket: Bucket }) {
  const active = !!bucket.running;
  const label = bucket.running?.title;

  return (
    <div className="flex flex-col items-center text-center">
      <div className="relative flex h-28 w-28 items-center justify-center">
        {active && (
          <motion.span
            className="absolute inset-0 rounded-full border border-brand-400/40"
            animate={{ scale: [1, 1.4, 1], opacity: [0.6, 0, 0.6] }}
            transition={{ duration: 1.8, repeat: Infinity, ease: "easeInOut" }}
          />
        )}

        <motion.div
          className="relative flex h-20 w-20 items-center justify-center rounded-full"
          style={{
            background: bucket.failed
              ? "radial-gradient(circle at 35% 30%, rgba(248,113,113,0.9), rgba(127,29,29,0.5))"
              : active
                ? "radial-gradient(circle at 35% 30%, #f2e2b8, #a9834a)"
                : "radial-gradient(circle at 35% 30%, rgba(226,199,137,0.35), rgba(42,42,46,0.55))",
            boxShadow: active ? "0 0 40px 6px rgba(204,166,96,0.35)" : "0 0 0 1px rgba(255,255,255,0.06)",
          }}
          animate={active ? { scale: [1, 1.08, 1] } : { scale: [1, 1.03, 1] }}
          transition={{ duration: active ? 1.4 : 4.5, repeat: Infinity, ease: "easeInOut" }}
        />

        <AnimatePresence>
          {bucket.justFinished && (
            <motion.div
              className="absolute -right-1 -top-1 flex h-7 w-7 items-center justify-center rounded-full bg-emerald-500 text-white shadow-lg"
              initial={{ scale: 0, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0, opacity: 0 }}
            >
              <IconCheck className="h-4 w-4" />
            </motion.div>
          )}
        </AnimatePresence>

        {bucket.failed && (
          <div
            className="absolute -left-1 -top-1 flex h-7 w-7 items-center justify-center rounded-full bg-red-500/90 text-white"
            title={bucket.failed.error_message}
          >
            <IconAlertTriangle className="h-4 w-4" />
          </div>
        )}

        {bucket.queuedCount > 0 && (
          <span className="badge absolute -bottom-1 bg-white/10 text-gray-300">{bucket.queuedCount} queued</span>
        )}
      </div>

      <h3 className="mt-4 text-sm font-medium text-gray-100">{stage.name}</h3>
      <p className="mt-1 min-h-[2.5rem] max-w-[13rem] text-xs text-gray-500">
        {active && label ? (
          <span className="text-brand-300">{truncate(label, 48)}</span>
        ) : (
          truncate(stage.role, 60)
        )}
      </p>

      {active && bucket.running && (
        <div className="mt-2 h-1 w-24 overflow-hidden rounded-full bg-white/5">
          <div
            className="h-full rounded-full bg-brand-400"
            style={{ width: `${Math.round(bucket.running.progress * 100)}%` }}
          />
        </div>
      )}
    </div>
  );
}
