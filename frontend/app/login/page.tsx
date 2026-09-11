"use client";

import { useState } from "react";
import { motion } from "framer-motion";
import { api } from "@/lib/api";

const FEATURES = [
  "AI finds the hooks, funny moments, and highlights automatically",
  "Word-by-word animated captions, burned in and ready to post",
  "Your fonts, colors, logo, and watermark on every clip",
  "One-tap upload straight to your own YouTube channel",
];

export default function LoginPage() {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function handleLogin() {
    setLoading(true);
    setError("");
    try {
      const { auth_url } = await api.googleLoginUrl();
      window.location.href = auth_url;
    } catch (e) {
      setError((e as Error).message);
      setLoading(false);
    }
  }

  return (
    <div className="relative flex min-h-screen items-center justify-center overflow-hidden px-6 py-20">
      <div
        className="pointer-events-none absolute inset-0 -z-10"
        style={{
          background:
            "radial-gradient(46rem 30rem at 50% -8%, rgba(204,166,96,0.14), transparent 62%), radial-gradient(30rem 24rem at 100% 100%, rgba(255,255,255,0.03), transparent 55%)",
        }}
      />

      <motion.div
        initial={{ opacity: 0, y: 14 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5, ease: "easeOut" }}
        className="w-full max-w-md text-center"
      >
        <p className="eyebrow mb-5">Personal AI shorts studio</p>
        <h1 className="mb-4 text-5xl font-extralight tracking-tight text-gray-50">ShortsForge</h1>
        <p className="mx-auto mb-14 max-w-xs text-[15px] font-light leading-relaxed text-gray-400">
          Turn long-form video into YouTube Shorts, automatically.
        </p>

        <div className="mb-10 space-y-5 border-y border-white/[0.07] py-9 text-left">
          {FEATURES.map((text, i) => (
            <div key={text} className="flex items-start gap-4">
              <span className="mt-[7px] font-mono text-[11px] text-brand-400">{String(i + 1).padStart(2, "0")}</span>
              <span className="text-[13px] font-light leading-relaxed text-gray-300">{text}</span>
            </div>
          ))}
        </div>

        <button onClick={handleLogin} disabled={loading} className="btn-primary w-full py-3">
          {loading ? (
            <>
              <span className="h-3.5 w-3.5 animate-spin rounded-full border border-ink/40 border-t-ink" />
              Redirecting…
            </>
          ) : (
            <>
              <svg viewBox="0 0 24 24" className="h-4 w-4" aria-hidden="true">
                <path
                  fill="currentColor"
                  d="M21.35 11.1h-9.17v2.73h6.51c-.33 3.81-3.5 5.44-6.5 5.44C8.36 19.27 5 16.25 5 12c0-4.1 3.2-7.27 7.2-7.27 3.09 0 4.9 1.97 4.9 1.97L19 4.72S16.56 2 12.1 2C6.42 2 2.03 6.8 2.03 12c0 5.05 4.13 10 10.22 10 5.35 0 9.25-3.67 9.25-9.09 0-1.15-.15-1.81-.15-1.81Z"
                />
              </svg>
              Sign in with Google
            </>
          )}
        </button>
        {error && <p className="mt-3 text-center text-xs text-red-400">{error}</p>}

        <p className="mt-8 text-[11px] font-light uppercase tracking-wider2 text-gray-600">
          Personal use only — your videos, your channel, your data
        </p>
      </motion.div>
    </div>
  );
}
