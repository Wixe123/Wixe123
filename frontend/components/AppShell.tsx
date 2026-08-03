"use client";

import { AnimatePresence, motion } from "framer-motion";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { api, clearToken, getToken } from "@/lib/api";
import {
  IconCopyStyle,
  IconDashboard,
  IconFlame,
  IconLogOut,
  IconPalette,
  IconQueue,
  IconSettings,
  IconTrendingUp,
  IconUpload,
} from "@/components/icons";
import type { User } from "@/lib/types";

const NAV_ITEMS = [
  { href: "/", label: "Dashboard", Icon: IconDashboard },
  { href: "/upload", label: "Upload", Icon: IconUpload },
  { href: "/queue", label: "Queue", Icon: IconQueue },
  { href: "/trending", label: "Trending", Icon: IconFlame },
  { href: "/analytics", label: "Analytics", Icon: IconTrendingUp },
  { href: "/style", label: "Style Analyzer", Icon: IconCopyStyle },
  { href: "/branding", label: "Branding", Icon: IconPalette },
  { href: "/settings", label: "Settings", Icon: IconSettings },
];

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
  const pathname = usePathname();
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
        <nav className="flex flex-1 flex-col gap-0.5">
          {NAV_ITEMS.map((item) => {
            const active = pathname === item.href;
            return (
              <Link key={item.href} href={item.href} className="relative">
                {active && (
                  <motion.div
                    layoutId="nav-active-desktop"
                    className="absolute inset-y-0 left-0 w-px bg-brand-400"
                    transition={{ type: "spring", stiffness: 500, damping: 40 }}
                  />
                )}
                <span
                  className={`relative flex items-center gap-3 py-2.5 pl-4 text-[13px] font-normal tracking-wide transition-colors ${
                    active ? "text-brand-300" : "text-gray-500 hover:text-gray-200"
                  }`}
                >
                  <item.Icon className="h-[17px] w-[17px]" strokeWidth={1.4} />
                  {item.label}
                </span>
              </Link>
            );
          })}
        </nav>
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

      <main className="flex-1 overflow-y-auto p-5 pb-24 md:p-12 md:pb-12">
        <AnimatePresence mode="wait">
          <motion.div
            key={pathname}
            initial={{ opacity: 0, y: 6 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.25, ease: "easeOut" }}
            className="mx-auto max-w-5xl"
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
                  className="absolute top-0 h-px w-8 bg-brand-400"
                  transition={{ type: "spring", stiffness: 500, damping: 40 }}
                />
              )}
              <item.Icon className={`h-5 w-5 ${active ? "text-brand-300" : "text-gray-500"}`} strokeWidth={1.4} />
              <span className={`text-[10px] font-normal ${active ? "text-brand-300" : "text-gray-500"}`}>
                {item.label}
              </span>
            </Link>
          );
        })}
      </nav>
    </div>
  );
}
