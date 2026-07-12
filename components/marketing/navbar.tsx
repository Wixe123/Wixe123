"use client";

import * as React from "react";
import Link from "next/link";
import { Menu, X } from "lucide-react";
import { Logo } from "@/components/layout/logo";
import { Button } from "@/components/ui/button";
import { ThemeToggle } from "@/components/theme-toggle";

const LINKS = [
  { label: "Product", href: "#product" },
  { label: "How it works", href: "#workflow" },
  { label: "Compare", href: "#compare" },
  { label: "Pricing", href: "#pricing" },
  { label: "FAQ", href: "#faq" },
];

export function Navbar() {
  const [open, setOpen] = React.useState(false);
  return (
    <header className="sticky top-0 z-40 border-b border-border/60 bg-background/70 backdrop-blur-xl">
      <div className="mx-auto flex h-16 max-w-7xl items-center px-4 sm:px-6 lg:px-8">
        <Logo />
        <nav className="ml-10 hidden items-center gap-7 md:flex">
          {LINKS.map((l) => (
            <a
              key={l.href}
              href={l.href}
              className="text-sm font-medium text-muted-foreground transition-colors hover:text-foreground"
            >
              {l.label}
            </a>
          ))}
        </nav>
        <div className="ml-auto hidden items-center gap-2 md:flex">
          <ThemeToggle />
          <Button variant="ghost" asChild>
            <Link href="/sign-in">Sign in</Link>
          </Button>
          <Button variant="gradient" asChild>
            <Link href="/sign-up">Start free</Link>
          </Button>
        </div>
        <button
          className="ml-auto flex size-9 items-center justify-center rounded-lg md:hidden"
          onClick={() => setOpen((o) => !o)}
        >
          {open ? <X className="size-5" /> : <Menu className="size-5" />}
        </button>
      </div>
      {open && (
        <div className="border-t border-border/60 bg-background px-4 py-4 md:hidden">
          <nav className="flex flex-col gap-4">
            {LINKS.map((l) => (
              <a key={l.href} href={l.href} onClick={() => setOpen(false)} className="text-sm font-medium">
                {l.label}
              </a>
            ))}
            <div className="flex items-center gap-2 pt-2">
              <Button variant="ghost" asChild className="flex-1">
                <Link href="/sign-in">Sign in</Link>
              </Button>
              <Button variant="gradient" asChild className="flex-1">
                <Link href="/sign-up">Start free</Link>
              </Button>
            </div>
          </nav>
        </div>
      )}
    </header>
  );
}
