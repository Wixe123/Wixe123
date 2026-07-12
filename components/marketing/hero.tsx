"use client";

import Link from "next/link";
import { motion } from "framer-motion";
import { ArrowRight, Play, Star } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";

const AVATAR_EMOJIS = ["🧴", "👟", "🐶", "☕", "🖥️", "🧢"];

export function Hero() {
  return (
    <section className="relative overflow-hidden pt-16 pb-20 sm:pt-24 sm:pb-28">
      <div className="bg-mesh pointer-events-none absolute inset-0 -z-10" />
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div className="mx-auto max-w-3xl text-center">
          <motion.div
            initial={{ opacity: 0, y: 12 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5 }}
          >
            <Badge variant="outline" className="glass mx-auto gap-1.5 px-3 py-1.5">
              <Star className="size-3 fill-primary text-primary" />
              Trusted by 2,400+ Shopify &amp; DTC brands
            </Badge>
          </motion.div>

          <motion.h1
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6, delay: 0.05 }}
            className="mt-6 font-display text-4xl font-extrabold tracking-tight text-balance sm:text-6xl"
          >
            UGC ads that look like a{" "}
            <span className="text-gradient">real person</span>, not an AI ad
          </motion.h1>

          <motion.p
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6, delay: 0.1 }}
            className="mx-auto mt-5 max-w-2xl text-lg text-muted-foreground text-balance"
          >
            Paste a product link, pick an audience, and ship a scroll-stopping,
            conversion-optimized UGC video in under 3 minutes. Built for Shopify,
            TikTok Shop, and performance marketers.
          </motion.p>

          <motion.div
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6, delay: 0.15 }}
            className="mt-8 flex flex-col items-center justify-center gap-3 sm:flex-row"
          >
            <Button size="lg" variant="gradient" asChild>
              <Link href="/sign-up">
                Create your first ad free <ArrowRight className="size-4" />
              </Link>
            </Button>
            <Button size="lg" variant="outline" asChild>
              <a href="#demo">
                <Play className="size-4" /> Watch 60s demo
              </a>
            </Button>
          </motion.div>

          <motion.p
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ duration: 0.6, delay: 0.25 }}
            className="mt-4 text-xs text-muted-foreground"
          >
            No credit card required · 3 free video credits
          </motion.p>
        </div>

        <motion.div
          id="demo"
          initial={{ opacity: 0, y: 40 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.7, delay: 0.2 }}
          className="relative mx-auto mt-16 max-w-5xl"
        >
          <div className="glass overflow-hidden rounded-3xl border p-2 shadow-2xl sm:p-3">
            <div className="grid grid-cols-2 gap-2 sm:grid-cols-4 sm:gap-3">
              {AVATAR_EMOJIS.map((emoji, i) => (
                <motion.div
                  key={emoji}
                  initial={{ opacity: 0, scale: 0.9 }}
                  animate={{ opacity: 1, scale: 1 }}
                  transition={{ duration: 0.4, delay: 0.3 + i * 0.06 }}
                  className="group relative aspect-9/16 overflow-hidden rounded-2xl bg-gradient-to-br from-secondary to-secondary/40"
                >
                  <div className="absolute inset-0 flex items-center justify-center text-6xl">
                    {emoji}
                  </div>
                  <div className="absolute inset-x-0 bottom-0 bg-gradient-to-t from-black/70 to-transparent p-3">
                    <div className="h-1.5 w-3/4 rounded-full bg-white/70" />
                    <div className="mt-1.5 h-1.5 w-1/2 rounded-full bg-white/40" />
                  </div>
                  <span className="absolute top-2 right-2 flex size-6 items-center justify-center rounded-full bg-black/40 text-[10px] font-semibold text-white backdrop-blur">
                    {88 + i}
                  </span>
                </motion.div>
              ))}
            </div>
          </div>
          <div className="absolute -top-10 -right-10 -z-10 size-56 animate-glow rounded-full bg-[var(--gradient-2)] opacity-30 blur-3xl" />
          <div className="absolute -bottom-10 -left-10 -z-10 size-56 animate-glow rounded-full bg-[var(--gradient-1)] opacity-30 blur-3xl" />
        </motion.div>
      </div>
    </section>
  );
}
