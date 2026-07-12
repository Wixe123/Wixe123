"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { NAV_GROUPS } from "./nav-items";
import { Logo } from "./logo";
import { cn } from "@/lib/utils";
import { Badge } from "@/components/ui/badge";
import { Progress } from "@/components/ui/progress";
import { DASHBOARD_STATS } from "@/lib/mock-data";
import { Zap } from "lucide-react";
import { Button } from "@/components/ui/button";

function NavLinks({ onNavigate }: { onNavigate?: () => void }) {
  const pathname = usePathname();
  return (
    <nav className="flex-1 space-y-6 overflow-y-auto px-3 py-4 no-scrollbar">
      {NAV_GROUPS.map((group) => (
        <div key={group.title}>
          <p className="px-3 pb-2 text-[11px] font-semibold tracking-wider text-muted-foreground uppercase">
            {group.title}
          </p>
          <div className="space-y-0.5">
            {group.items.map((item) => {
              const active =
                item.href === "/dashboard"
                  ? pathname === "/dashboard"
                  : pathname?.startsWith(item.href);
              return (
                <Link
                  key={item.href}
                  href={item.href}
                  onClick={onNavigate}
                  className={cn(
                    "group flex items-center gap-2.5 rounded-xl px-3 py-2 text-sm font-medium transition-colors",
                    active
                      ? "bg-primary/12 text-primary"
                      : "text-muted-foreground hover:bg-secondary hover:text-foreground"
                  )}
                >
                  <item.icon
                    className={cn(
                      "size-4 shrink-0",
                      active ? "text-primary" : "text-muted-foreground group-hover:text-foreground"
                    )}
                  />
                  <span className="flex-1 truncate">{item.label}</span>
                  {item.badge && (
                    <Badge variant="gradient" className="px-1.5 py-0 text-[10px]">
                      {item.badge}
                    </Badge>
                  )}
                </Link>
              );
            })}
          </div>
        </div>
      ))}
    </nav>
  );
}

function CreditsCard() {
  const pct = Math.round((DASHBOARD_STATS.creditsRemaining / DASHBOARD_STATS.creditsTotal) * 100);
  return (
    <div className="m-3 rounded-2xl border border-border bg-secondary/60 p-4">
      <div className="flex items-center justify-between text-xs font-medium">
        <span className="flex items-center gap-1.5 text-foreground">
          <Zap className="size-3.5 text-primary" /> Credits
        </span>
        <span className="text-muted-foreground">
          {DASHBOARD_STATS.creditsRemaining}/{DASHBOARD_STATS.creditsTotal}
        </span>
      </div>
      <Progress value={pct} className="mt-2 h-1.5" />
      <Button asChild variant="gradient" size="sm" className="mt-3 w-full">
        <Link href="/dashboard/billing">Upgrade plan</Link>
      </Button>
    </div>
  );
}

export function Sidebar() {
  return (
    <aside className="hidden w-[260px] shrink-0 border-r border-border bg-card/60 lg:flex lg:flex-col">
      <div className="flex h-16 items-center border-b border-border px-5">
        <Logo href="/dashboard" />
      </div>
      <NavLinks />
      <CreditsCard />
    </aside>
  );
}

export function SidebarMobileContent({ onNavigate }: { onNavigate?: () => void }) {
  return (
    <div className="flex h-full flex-col">
      <div className="flex h-16 items-center px-1">
        <Logo href="/dashboard" />
      </div>
      <NavLinks onNavigate={onNavigate} />
      <CreditsCard />
    </div>
  );
}
