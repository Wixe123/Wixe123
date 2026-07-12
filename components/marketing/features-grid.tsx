"use client";

import { motion } from "framer-motion";
import {
  Sparkles, Mic, Users, ScrollText, SplitSquareHorizontal, Palette,
  TrendingUp, ImageIcon as ImageIconLucide,
} from "lucide-react";
import { Card } from "@/components/ui/card";

const FEATURES = [
  {
    icon: ScrollText,
    title: "Marketing-psychology scripts",
    desc: "Every script is built from hook, pattern interrupt, pain point, story, social proof, and CTA — scored for quality before you render.",
  },
  {
    icon: Users,
    title: "200+ realistic AI avatars",
    desc: "Natural blinking, breathing, gestures, and micro-imperfections so viewers see a person, not a render.",
  },
  {
    icon: Mic,
    title: "Natural voices, 10 languages",
    desc: "Emotion, pacing, and pause control across US, UK, Australian, Irish, Indian, and Canadian accents.",
  },
  {
    icon: TrendingUp,
    title: "Viral optimization engine",
    desc: "Predicts hook strength, retention, CTR, and virality — then tells you exactly what to fix.",
  },
  {
    icon: SplitSquareHorizontal,
    title: "One-click A/B variants",
    desc: "Generate 3 variants with different hooks, voices, and CTAs to find your winner faster.",
  },
  {
    icon: Palette,
    title: "Brand kit auto-apply",
    desc: "Upload your logo, fonts, and colors once — every export inherits your brand automatically.",
  },
  {
    icon: ImageIconLucide,
    title: "Thumbnail & copy generator",
    desc: "10 scroll-stopping thumbnails and platform-native captions, hashtags, and ad copy in seconds.",
  },
  {
    icon: Sparkles,
    title: "Built-in marketing assistant",
    desc: "Ask it to make a hook funnier, more luxury, or rewritten for Gen Z — right inside the editor.",
  },
];

export function FeaturesGrid() {
  return (
    <section id="product" className="mx-auto max-w-7xl px-4 py-24 sm:px-6 lg:px-8">
      <div className="mx-auto max-w-2xl text-center">
        <h2 className="font-display text-3xl font-bold tracking-tight sm:text-4xl">
          Everything a performance team needs — in one studio
        </h2>
        <p className="mt-4 text-muted-foreground">
          Not just a video generator. A full UGC production pipeline built around
          what actually converts.
        </p>
      </div>
      <div className="mt-14 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {FEATURES.map((f, i) => (
          <motion.div
            key={f.title}
            initial={{ opacity: 0, y: 16 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: "-40px" }}
            transition={{ duration: 0.4, delay: (i % 4) * 0.06 }}
          >
            <Card className="h-full p-6 transition-shadow hover:shadow-lg">
              <span className="flex size-10 items-center justify-center rounded-xl bg-primary/12 text-primary">
                <f.icon className="size-5" />
              </span>
              <h3 className="mt-4 font-display font-semibold">{f.title}</h3>
              <p className="mt-1.5 text-sm text-muted-foreground">{f.desc}</p>
            </Card>
          </motion.div>
        ))}
      </div>
    </section>
  );
}
