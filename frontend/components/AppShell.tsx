"use client";

import { AnimatePresence, motion } from "framer-motion";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { api, clearToken, getToken } from "@/lib/api";
import {
  IconDashboard,
  IconLogOut,
  IconPalette,
  IconQueue,
  IconSettings,
  IconUpload,
} from "@/components/icons";
import type { User } from "@/lib/types";

const NAV_ITEMS = [
  { href: "/", label: "Dashboard", Icon: IconDashboard },
  { href: "/upload", label: "Upload", Icon: IconUpload },
  { href: "/queue", label: "Queue", Icon: IconQueue },
  { href: "/branding", label: "Branding", Icon: IconPalette },
  { href: "/settings", label: "Settings", Icon: IconSettings },
];

function Logo({ size = 32 }: { size?: number }) {
  return (
    <div
      className="flex shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-brand-400 via-brand-500 to-accent-500 font-bold text-white shadow-[0_1px_0_0_rgba(255,255,255,0.35)_inset,0_6px_16px_-6px_rgba(124,58,237,0.7)]"
      style={{ width: size, height: size, fontSize: size * 0.4 }}
    >
      SF
    </div>
  );
}

export default function AppShell({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!getToken()) {
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
      <div className="flex h-screen items-center justify-center gap-3 text-gray-400">
        <div className="h-4 w-4 animate-spin rounded-full border-2 border-brand-500 border-t-transparent" />
        Loading ShortsForge…
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
      <header className="sticky top-0 z-20 flex items-center justify-between border-b border-white/[0.06] bg-base-950/80 px-4 py-3 backdrop-blur-md md:hidden">
        <div className="flex items-center gap-2">
          <Logo size={28} />
          <span className="font-semibold tracking-tight">ShortsForge</span>
        </div>
        {user && (
          <button onClick={signOut} className="flex items-center gap-2">
            {user.avatar_url ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={user.avatar_url} alt="" className="h-7 w-7 rounded-full ring-1 ring-white/10" />
            ) : (
              <div className="flex h-7 w-7 items-center justify-center rounded-full bg-base-800 text-xs font-medium text-gray-300 ring-1 ring-white/10">
                {(user.name || user.email || "?").slice(0, 1).toUpperCase()}
              </div>
            )}
          </button>
        )}
      </header>

      {/* Desktop sidebar */}
      <aside className="hidden w-64 shrink-0 flex-col border-r border-white/[0.06] bg-base-950/60 p-4 md:flex">
        <div className="mb-8 flex items-center gap-2.5 px-2 pt-1">
          <Logo />
          <span className="text-lg font-semibold tracking-tight">ShortsForge</span>
        </div>
        <nav className="flex flex-1 flex-col gap-1">
          {NAV_ITEMS.map((item) => {
            const active = pathname === item.href;
            return (
              <Link key={item.href} href={item.href} className="relative">
                {active && (
                  <motion.div
                    layoutId="nav-active-desktop"
                    className="absolute inset-0 rounded-lg bg-gradient-to-r from-brand-500/20 to-accent-500/5 ring-1 ring-inset ring-brand-500/30"
                    transition={{ type: "spring", stiffness: 500, damping: 40 }}
                  />
                )}
                <span
                  className={`relative flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors ${
                    active ? "text-white" : "text-gray-400 hover:text-gray-100"
                  }`}
                >
                  <item.Icon className={`h-[18px] w-[18px] ${active ? "text-brand-400" : ""}`} />
                  {item.label}
                </span>
              </Link>
            );
          })}
        </nav>
        {user && (
          <div className="flex items-center gap-3 rounded-xl border border-white/[0.06] bg-white/[0.02] p-3">
            {user.avatar_url ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={user.avatar_url} alt="" className="h-9 w-9 rounded-full ring-1 ring-white/10" />
            ) : (
              <div className="flex h-9 w-9 items-center justify-center rounded-full bg-base-800 text-sm font-medium text-gray-300 ring-1 ring-white/10">
                {(user.name || user.email || "?").slice(0, 1).toUpperCase()}
              </div>
            )}
            <div className="min-w-0 flex-1">
              <p className="truncate text-sm font-medium text-gray-100">{user.name || user.email}</p>
              <button
                onClick={signOut}
                className="flex items-center gap-1 text-xs text-gray-500 transition hover:text-gray-300"
              >
                <IconLogOut className="h-3 w-3" />
                Sign out
              </button>
            </div>
          </div>
        )}
      </aside>

      <main className="flex-1 overflow-y-auto p-4 pb-24 md:p-8 md:pb-8">
        <AnimatePresence mode="wait">
          <motion.div
            key={pathname}
            initial={{ opacity: 0, y: 6 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.2, ease: "easeOut" }}
          >
            {children}
          </motion.div>
        </AnimatePresence>
      </main>

      {/* Mobile bottom tab bar */}
      <nav
        className="fixed inset-x-0 bottom-0 z-20 flex border-t border-white/[0.06] bg-base-950/90 backdrop-blur-md md:hidden"
        style={{ paddingBottom: "env(safe-area-inset-bottom)" }}
      >
        {NAV_ITEMS.map((item) => {
          const active = pathname === item.href;
          return (
            <Link key={item.href} href={item.href} className="relative flex flex-1 flex-col items-center gap-1 py-2.5">
              {active && (
                <motion.div
                  layoutId="nav-active-mobile"
                  className="absolute top-1 h-0.5 w-8 rounded-full bg-brand-400"
                  transition={{ type: "spring", stiffness: 500, damping: 40 }}
                />
              )}
              <item.Icon className={`h-5 w-5 ${active ? "text-brand-400" : "text-gray-500"}`} />
              <span className={`text-[10px] font-medium ${active ? "text-brand-400" : "text-gray-500"}`}>
                {item.label}
              </span>
            </Link>
          );
        })}
      </nav>
    </div>
  );
}
