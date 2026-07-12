"use client";

import * as React from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Menu, Search, Bell, ChevronDown, LogOut, Settings, User } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { ThemeToggle } from "@/components/theme-toggle";
import { Sheet, SheetContent, SheetTrigger } from "@/components/ui/sheet";
import { SidebarMobileContent } from "./sidebar";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";

type SessionUser = { name: string; email: string; initials: string };

export function Topbar({ title, user }: { title?: string; user: SessionUser }) {
  const [open, setOpen] = React.useState(false);
  const router = useRouter();

  async function handleLogout() {
    await fetch("/api/auth/logout", { method: "POST" });
    router.push("/");
    router.refresh();
  }

  return (
    <header className="sticky top-0 z-30 flex h-16 items-center gap-3 border-b border-border bg-background/80 px-4 backdrop-blur-md sm:px-6">
      <Sheet open={open} onOpenChange={setOpen}>
        <SheetTrigger asChild>
          <Button variant="ghost" size="icon" className="lg:hidden">
            <Menu className="size-5" />
          </Button>
        </SheetTrigger>
        <SheetContent side="left" className="w-[280px] p-4">
          <SidebarMobileContent onNavigate={() => setOpen(false)} />
        </SheetContent>
      </Sheet>

      {title && <h1 className="font-display text-lg font-semibold tracking-tight">{title}</h1>}

      <div className="ml-auto flex items-center gap-2">
        <div className="relative hidden md:block">
          <Search className="absolute top-1/2 left-3 size-4 -translate-y-1/2 text-muted-foreground" />
          <Input placeholder="Search projects, scripts…" className="w-64 pl-9" />
        </div>
        <Button variant="ghost" size="icon" className="relative">
          <Bell className="size-4.5" />
          <span className="absolute top-1.5 right-1.5 size-2 rounded-full bg-primary" />
        </Button>
        <ThemeToggle />
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <button className="flex items-center gap-2 rounded-xl border border-border py-1 pr-2 pl-1 hover:bg-secondary">
              <Avatar className="size-7">
                <AvatarFallback className="bg-[linear-gradient(135deg,var(--gradient-1),var(--gradient-2))] text-white text-xs">
                  {user.initials}
                </AvatarFallback>
              </Avatar>
              <ChevronDown className="size-3.5 text-muted-foreground" />
            </button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end" className="w-56">
            <DropdownMenuLabel>
              <p className="text-sm font-medium">{user.name}</p>
              <p className="text-xs font-normal text-muted-foreground">{user.email}</p>
            </DropdownMenuLabel>
            <DropdownMenuSeparator />
            <DropdownMenuItem asChild>
              <Link href="/dashboard/settings"><User className="size-4" /> Profile</Link>
            </DropdownMenuItem>
            <DropdownMenuItem asChild>
              <Link href="/dashboard/settings"><Settings className="size-4" /> Settings</Link>
            </DropdownMenuItem>
            <DropdownMenuSeparator />
            <DropdownMenuItem onSelect={handleLogout}>
              <LogOut className="size-4" /> Log out
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </div>
    </header>
  );
}
