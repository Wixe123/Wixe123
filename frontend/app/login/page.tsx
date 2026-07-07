"use client";

import { useState } from "react";
import { motion } from "framer-motion";
import { api } from "@/lib/api";
import { IconPalette, IconScissors, IconSparkles, IconUploadCloud } from "@/components/icons";

const FEATURES = [
  { Icon: IconScissors, text: "AI finds the hooks, funny moments, and highlights automatically" },
  { Icon: IconSparkles, text: "Word-by-word animated captions, burned in and ready to post" },
  { Icon: IconPalette, text: "Your fonts, colors, logo, and watermark on every clip" },
  { Icon: IconUploadCloud, text: "One-tap upload straight to your own YouTube channel" },
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
    <div className="relative flex min-h-screen items-center justify-center overflow-hidden px-4 py-16">
      <div
        className="pointer-events-none absolute inset-0 -z-10"
        style={{
          background:
            "radial-gradient(38rem 24rem at 20% 10%, rgba(124,58,237,0.28), transparent 60%), radial-gradient(32rem 22rem at 85% 15%, rgba(34,211,238,0.16), transparent 55%), radial-gradient(40rem 30rem at 50% 100%, rgba(124,58,237,0.14), transparent 60%)",
        }}
      />

      <motion.div
        initial={{ opacity: 0, y: 12 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.35, ease: "easeOut" }}
        className="w-full max-w-sm"
      >
        <div className="mb-8 flex flex-col items-center text-center">
          <div className="mb-4 flex h-14 w-14 items-center justify-center rounded-2xl bg-gradient-to-br from-brand-400 via-brand-500 to-accent-500 text-xl font-bold text-white shadow-[0_1px_0_0_rgba(255,255,255,0.35)_inset,0_10px_30px_-8px_rgba(124,58,237,0.7)]">
            SF
          </div>
          <h1 className="text-2xl font-semibold tracking-tight">ShortsForge</h1>
          <p className="mt-2 text-sm text-gray-400">
            Turn long-form video into YouTube Shorts, automatically.
          </p>
        </div>

        <div className="card p-6">
          <ul className="mb-6 space-y-3.5">
            {FEATURES.map(({ Icon, text }) => (
              <li key={text} className="flex items-start gap-3 text-sm text-gray-300">
                <span className="icon-chip mt-0.5 bg-brand-500/15 text-brand-400">
                  <Icon className="h-4 w-4" />
                </span>
                <span className="pt-1.5 leading-snug">{text}</span>
              </li>
            ))}
          </ul>

          <button onClick={handleLogin} disabled={loading} className="btn-primary w-full py-2.5">
            {loading ? (
              <>
                <span className="h-4 w-4 animate-spin rounded-full border-2 border-white/40 border-t-white" />
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
        </div>

        <p className="mt-6 text-center text-xs text-gray-600">
          Personal use only — your videos, your channel, your data.
        </p>
      </motion.div>
    </div>
  );
}
