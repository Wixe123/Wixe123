"use client";

import { motion } from "framer-motion";
import { Star } from "lucide-react";
import { Card } from "@/components/ui/card";
import { TESTIMONIALS } from "@/lib/mock-data";

export function Testimonials() {
  return (
    <section className="bg-secondary/30 py-24">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div className="mx-auto max-w-2xl text-center">
          <h2 className="font-display text-3xl font-bold tracking-tight sm:text-4xl">
            Loved by creators, agencies, and DTC teams
          </h2>
        </div>
        <div className="mt-14 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {TESTIMONIALS.map((t, i) => (
            <motion.div
              key={t.name}
              initial={{ opacity: 0, y: 16 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, margin: "-40px" }}
              transition={{ duration: 0.4, delay: i * 0.07 }}
            >
              <Card className="h-full p-6">
                <div className="flex gap-0.5 text-primary">
                  {Array.from({ length: 5 }).map((_, s) => (
                    <Star key={s} className="size-3.5 fill-current" />
                  ))}
                </div>
                <p className="mt-3 text-sm leading-relaxed">&ldquo;{t.quote}&rdquo;</p>
                <div className="mt-5 flex items-center gap-2.5">
                  <span className="flex size-9 items-center justify-center rounded-full bg-secondary text-lg">
                    {t.avatarEmoji}
                  </span>
                  <div>
                    <p className="text-sm font-semibold">{t.name}</p>
                    <p className="text-xs text-muted-foreground">{t.role}</p>
                  </div>
                </div>
              </Card>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}
