"use client";

import { motion } from "framer-motion";
import type { ComponentType, SVGProps } from "react";

type Tone = "default" | "danger" | "success";

const TONE_STYLES: Record<Tone, { value: string; chipBg: string; chipFg: string }> = {
  default: { value: "text-gray-50", chipBg: "bg-brand-500/15", chipFg: "text-brand-400" },
  danger: { value: "text-red-400", chipBg: "bg-red-500/15", chipFg: "text-red-400" },
  success: { value: "text-emerald-400", chipBg: "bg-emerald-500/15", chipFg: "text-emerald-400" },
};

export default function StatCard({
  label,
  value,
  icon: Icon,
  tone = "default",
}: {
  label: string;
  value: string | number;
  icon: ComponentType<SVGProps<SVGSVGElement>>;
  tone?: Tone;
}) {
  const styles = TONE_STYLES[tone];

  return (
    <motion.div
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.25 }}
      className="card p-5"
    >
      <div className="flex items-center justify-between">
        <span className="text-sm text-gray-400">{label}</span>
        <span className={`icon-chip ${styles.chipBg} ${styles.chipFg}`}>
          <Icon className="h-[18px] w-[18px]" />
        </span>
      </div>
      <p className={`mt-3 text-3xl font-semibold tracking-tight ${styles.value}`}>{value}</p>
    </motion.div>
  );
}
