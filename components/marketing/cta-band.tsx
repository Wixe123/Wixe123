import Link from "next/link";
import { ArrowRight } from "lucide-react";
import { Button } from "@/components/ui/button";

export function CtaBand() {
  return (
    <section className="mx-auto max-w-7xl px-4 pb-24 sm:px-6 lg:px-8">
      <div className="relative overflow-hidden rounded-3xl bg-[linear-gradient(120deg,var(--gradient-1),var(--gradient-2)_55%,var(--gradient-3))] px-6 py-16 text-center text-white sm:px-16">
        <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_top,rgba(255,255,255,0.25),transparent_60%)]" />
        <h2 className="font-display text-3xl font-bold tracking-tight sm:text-4xl">
          Ship your next winning ad in the next 3 minutes
        </h2>
        <p className="mx-auto mt-4 max-w-xl text-white/85">
          Join thousands of brands and agencies replacing UGC agencies and stock
          creators with CreatorAI.
        </p>
        <Button size="lg" variant="secondary" asChild className="mt-8 text-foreground">
          <Link href="/sign-up">
            Start creating free <ArrowRight className="size-4" />
          </Link>
        </Button>
      </div>
    </section>
  );
}
