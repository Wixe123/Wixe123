"use client";

import * as React from "react";
import { ChevronDown } from "lucide-react";
import { FAQS } from "@/lib/mock-data";
import { cn } from "@/lib/utils";

function FaqItem({ q, a }: { q: string; a: string }) {
  const [open, setOpen] = React.useState(false);
  return (
    <div className="rounded-2xl border border-border bg-card">
      <button
        onClick={() => setOpen((o) => !o)}
        className="flex w-full items-center justify-between gap-4 p-5 text-left"
      >
        <span className="font-medium">{q}</span>
        <ChevronDown className={cn("size-4 shrink-0 text-muted-foreground transition-transform", open && "rotate-180")} />
      </button>
      {open && <p className="px-5 pb-5 text-sm text-muted-foreground">{a}</p>}
    </div>
  );
}

export function FAQ() {
  return (
    <section id="faq" className="mx-auto max-w-3xl px-4 py-24 sm:px-6 lg:px-8">
      <div className="text-center">
        <h2 className="font-display text-3xl font-bold tracking-tight sm:text-4xl">
          Frequently asked questions
        </h2>
      </div>
      <div className="mt-10 space-y-3">
        {FAQS.map((f) => (
          <FaqItem key={f.q} {...f} />
        ))}
      </div>
    </section>
  );
}
