"use client";

import { motion } from "framer-motion";
import type { ComponentType, SVGProps } from "react";

type Tone = "default" | "danger" | "success";

const TONE_VALUE: Record<Tone, string> = {
  default: "text-gray-50",
  danger: "text-red-400/90",
  success: "text-emerald-400/90",
};

const TONE_ICON: Record<Tone, string> = {
  default: "text-gray-600",
  danger: "text-red-400/70",
  success: "text-emerald-400/70",
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
  return (
    <motion.div
      initial={{ opacity: 0, y: 6 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.25 }}
      className="card px-5 py-4"
    >
      <div className="flex items-center justify-between">
        <span className="text-[11px] font-medium uppercase tracking-wider2 text-gray-500">{label}</span>
        <Icon className={`h-4 w-4 ${TONE_ICON[tone]}`} strokeWidth={1.3} />
      </div>
      <p className={`mt-3 text-3xl font-extralight tracking-tight ${TONE_VALUE[tone]}`}>{value}</p>
    </motion.div>
  );
}
