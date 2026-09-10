"use client";

import { AnimatePresence, motion } from "framer-motion";
import { useEffect, useRef, useState } from "react";
import AppShell from "@/components/AppShell";
import { IconAlertTriangle, IconCheck } from "@/components/icons";
import { api } from "@/lib/api";
import type { JobType, ProcessingJob } from "@/lib/types";

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

export default function AgentWorldPage() {
  const [jobs, setJobs] = useState<ProcessingJob[]>([]);
  const [error, setError] = useState("");
  const [flash, setFlash] = useState<Record<string, boolean>>({});
  const prevSuccessIds = useRef<Set<string>>(new Set());

  async function load() {
    try {
      const data = await api.listJobs();

      const newlyDone: Record<string, boolean> = {};
      for (const j of data) {
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
      prevSuccessIds.current = new Set(data.filter((j) => j.status === "success").map((j) => j.id));

      setJobs(data);
      setError("");
    } catch (e) {
      setError((e as Error).message);
    }
  }

  useEffect(() => {
    load();
    const interval = setInterval(load, 3000);
    return () => clearInterval(interval);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

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
        <h1 className="text-3xl font-extralight tracking-tight">Agent world</h1>
        <p className="mt-1 text-sm text-gray-500">
          Where your ShortsForge pipeline lives — live status, not a diagram.
        </p>
      </div>

      {error && <p className="mb-4 text-sm text-red-400">{error}</p>}

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
