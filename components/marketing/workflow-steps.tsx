"use client";

import { motion } from "framer-motion";
import { Link2, Users2, MonitorSmartphone, Target } from "lucide-react";

const STEPS = [
  {
    icon: Link2,
    step: "01",
    title: "Drop in your product",
    desc: "Paste an Amazon or Shopify link, upload images, or a PDF. We auto-scrape title, features, price, reviews, and brand.",
  },
  {
    icon: Users2,
    step: "02",
    title: "Pick your audience",
    desc: "Busy moms, gym lovers, runners, entrepreneurs — choose from 13+ ready-made audiences or write your own.",
  },
  {
    icon: MonitorSmartphone,
    step: "03",
    title: "Choose platform & objective",
    desc: "TikTok, Instagram, Amazon, Shopify — pick the platform and the objective, from sales to brand awareness.",
  },
  {
    icon: Target,
    step: "04",
    title: "Generate & ship",
    desc: "Get 5 scripted variants with quality scores, pick an avatar and voice, and render in under 3 minutes.",
  },
];

export function WorkflowSteps() {
  return (
    <section id="workflow" className="bg-secondary/30 py-24">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div className="mx-auto max-w-2xl text-center">
          <h2 className="font-display text-3xl font-bold tracking-tight sm:text-4xl">
            From product link to finished ad in 4 steps
          </h2>
          <p className="mt-4 text-muted-foreground">
            No editing timeline, no green screen, no camera. Just a link and a
            direction.
          </p>
        </div>
        <div className="mt-14 grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-4">
          {STEPS.map((s, i) => (
            <motion.div
              key={s.step}
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, margin: "-40px" }}
              transition={{ duration: 0.45, delay: i * 0.08 }}
              className="relative rounded-2xl border border-border bg-card p-6"
            >
              <span className="font-display text-4xl font-extrabold text-primary/15">
                {s.step}
              </span>
              <span className="mt-2 flex size-10 items-center justify-center rounded-xl bg-primary/12 text-primary">
                <s.icon className="size-5" />
              </span>
              <h3 className="mt-4 font-display font-semibold">{s.title}</h3>
              <p className="mt-1.5 text-sm text-muted-foreground">{s.desc}</p>
              {i < STEPS.length - 1 && (
                <div className="absolute top-1/2 -right-3 hidden h-px w-6 bg-border lg:block" />
              )}
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}
