"use client";

import { useState } from "react";
import { api } from "@/lib/api";

export default function LoginPage() {
  const [loading, setLoading] = useState(false);

  async function handleLogin() {
    setLoading(true);
    try {
      const { auth_url } = await api.googleLoginUrl();
      window.location.href = auth_url;
    } catch {
      setLoading(false);
    }
  }

  return (
    <div className="flex h-screen flex-col items-center justify-center gap-8 bg-gradient-to-b from-base-950 to-base-900 px-4 text-center">
      <div className="flex items-center gap-2">
        <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-gradient-to-br from-brand-500 to-accent-500 font-bold">
          SF
        </div>
        <h1 className="text-2xl font-semibold">ShortsForge</h1>
      </div>
      <p className="max-w-sm text-sm text-gray-400">
        Turn your long-form videos into YouTube Shorts with AI clip detection,
        animated subtitles, and one-click upload to your own channel.
      </p>
      <button onClick={handleLogin} disabled={loading} className="btn-primary px-6 py-3">
        {loading ? "Redirecting…" : "Sign in with Google"}
      </button>
    </div>
  );
}
