"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { api, clearToken, getToken } from "@/lib/api";
import type { User } from "@/lib/types";

const NAV_ITEMS = [
  { href: "/", label: "Dashboard", icon: "📊" },
  { href: "/upload", label: "Upload", icon: "⬆️" },
  { href: "/queue", label: "Queue", icon: "🗂️" },
  { href: "/branding", label: "Branding", icon: "🎨" },
  { href: "/settings", label: "Settings", icon: "⚙️" },
];

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
      <div className="flex h-screen items-center justify-center text-gray-400">
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
      <header className="sticky top-0 z-20 flex items-center justify-between border-b border-base-700 bg-base-900/90 px-4 py-3 backdrop-blur-sm md:hidden">
        <div className="flex items-center gap-2">
          <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-gradient-to-br from-brand-500 to-accent-500 text-xs font-bold">
            SF
          </div>
          <span className="font-semibold">ShortsForge</span>
        </div>
        {user && (
          <button onClick={signOut} className="flex items-center gap-2">
            {user.avatar_url ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={user.avatar_url} alt="" className="h-7 w-7 rounded-full" />
            ) : (
              <div className="h-7 w-7 rounded-full bg-base-700" />
            )}
          </button>
        )}
      </header>

      {/* Desktop sidebar */}
      <aside className="hidden w-60 shrink-0 flex-col border-r border-base-700 bg-base-900/60 p-4 md:flex">
        <div className="mb-8 flex items-center gap-2 px-2">
          <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-gradient-to-br from-brand-500 to-accent-500 text-sm font-bold">
            SF
          </div>
          <span className="text-lg font-semibold">ShortsForge</span>
        </div>
        <nav className="flex flex-1 flex-col gap-1">
          {NAV_ITEMS.map((item) => {
            const active = pathname === item.href;
            return (
              <Link
                key={item.href}
                href={item.href}
                className={`flex items-center gap-3 rounded-lg px-3 py-2 text-sm transition ${
                  active
                    ? "bg-brand-500/15 text-brand-400 shadow-glow"
                    : "text-gray-400 hover:bg-base-800 hover:text-gray-100"
                }`}
              >
                <span>{item.icon}</span>
                {item.label}
              </Link>
            );
          })}
        </nav>
        {user && (
          <div className="flex items-center gap-3 rounded-lg border border-base-700 p-3">
            {user.avatar_url ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={user.avatar_url} alt="" className="h-8 w-8 rounded-full" />
            ) : (
              <div className="h-8 w-8 rounded-full bg-base-700" />
            )}
            <div className="min-w-0 flex-1">
              <p className="truncate text-sm font-medium">{user.name || user.email}</p>
              <button onClick={signOut} className="text-xs text-gray-500 hover:text-gray-300">
                Sign out
              </button>
            </div>
          </div>
        )}
      </aside>

      <main className="flex-1 overflow-y-auto p-4 pb-24 md:p-8 md:pb-8">{children}</main>

      {/* Mobile bottom tab bar */}
      <nav
        className="fixed inset-x-0 bottom-0 z-20 flex border-t border-base-700 bg-base-900/95 backdrop-blur-sm md:hidden"
        style={{ paddingBottom: "env(safe-area-inset-bottom)" }}
      >
        {NAV_ITEMS.map((item) => {
          const active = pathname === item.href;
          return (
            <Link
              key={item.href}
              href={item.href}
              className={`flex flex-1 flex-col items-center gap-0.5 py-2 text-[11px] ${
                active ? "text-brand-400" : "text-gray-500"
              }`}
            >
              <span className="text-lg leading-none">{item.icon}</span>
              {item.label}
            </Link>
          );
        })}
      </nav>
    </div>
  );
}
