"use client";

import { motion } from "framer-motion";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { api, clearToken, getToken } from "@/lib/api";
import { IconLogOut } from "@/components/icons";
import type { User } from "@/lib/types";

function Logo({ size = 30 }: { size?: number }) {
  return (
    <div
      className="flex shrink-0 items-center justify-center rounded-md border border-brand-400/30 bg-brand-400/[0.06] font-light tracking-wide text-brand-300"
      style={{ width: size, height: size, fontSize: size * 0.36 }}
    >
      SF
    </div>
  );
}

export default function AppShell({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!getToken()) {
      setLoading(false);
      router.replace("/login");
      return;
    }
    api
      .me()
      .then(setUser)
      .catch(() => {
        clearToken();
        router.replace("/login");
      })
      .finally(() => setLoading(false));
  }, [router]);

  if (loading) {
    return (
      <div className="flex h-screen items-center justify-center gap-3 text-gray-500">
        <div className="h-3.5 w-3.5 animate-spin rounded-full border border-brand-400 border-t-transparent" />
        <span className="text-sm font-light tracking-wide">Loading ShortsForge…</span>
      </div>
    );
  }

  function signOut() {
    clearToken();
    router.replace("/login");
  }

  return (
    <div className="flex min-h-screen flex-col md:flex-row">
      {/* Mobile top bar */}
      <header className="sticky top-0 z-20 flex items-center justify-between border-b border-white/[0.06] bg-base-950/85 px-4 py-3 backdrop-blur-md md:hidden">
        <div className="flex items-center gap-2.5">
          <Logo size={26} />
          <span className="text-[15px] font-light tracking-wide text-gray-100">ShortsForge</span>
        </div>
        {user && (
          <button onClick={signOut} className="flex items-center gap-2">
            {user.avatar_url ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={user.avatar_url} alt="" className="h-7 w-7 rounded-full ring-1 ring-white/10" />
            ) : (
              <div className="flex h-7 w-7 items-center justify-center rounded-full bg-base-800 text-xs font-light text-gray-300 ring-1 ring-white/10">
                {(user.name || user.email || "?").slice(0, 1).toUpperCase()}
              </div>
            )}
          </button>
        )}
      </header>

      {/* Desktop sidebar */}
      <aside className="hidden w-64 shrink-0 flex-col border-r border-white/[0.06] bg-base-950/50 px-5 py-6 md:flex">
        <div className="mb-10 flex items-center gap-3">
          <Logo />
          <span className="text-[15px] font-light tracking-wide text-gray-100">ShortsForge</span>
        </div>
        <div className="flex-1" />
        {user && (
          <div className="flex items-center gap-3 border-t border-white/[0.06] pt-4">
            {user.avatar_url ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={user.avatar_url} alt="" className="h-8 w-8 rounded-full ring-1 ring-white/10" />
            ) : (
              <div className="flex h-8 w-8 items-center justify-center rounded-full bg-base-800 text-xs font-light text-gray-300 ring-1 ring-white/10">
                {(user.name || user.email || "?").slice(0, 1).toUpperCase()}
              </div>
            )}
            <div className="min-w-0 flex-1">
              <p className="truncate text-[13px] font-normal text-gray-200">{user.name || user.email}</p>
              <button
                onClick={signOut}
                className="flex items-center gap-1 text-[11px] text-gray-500 transition hover:text-gray-300"
              >
                <IconLogOut className="h-3 w-3" />
                Sign out
              </button>
            </div>
          </div>
        )}
      </aside>

      <main className="flex-1 overflow-y-auto p-5 pb-8 md:p-12">
        <motion.div
          initial={{ opacity: 0, y: 6 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.25, ease: "easeOut" }}
          className="mx-auto max-w-5xl"
        >
          {children}
        </motion.div>
      </main>
    </div>
  );
}
