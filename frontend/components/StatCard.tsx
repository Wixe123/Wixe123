"use client";

import { motion } from "framer-motion";

export default function StatCard({
  label,
  value,
  icon,
  tone = "default",
}: {
  label: string;
  value: string | number;
  icon: string;
  tone?: "default" | "danger" | "success";
}) {
  const toneClasses =
    tone === "danger"
      ? "text-red-400"
      : tone === "success"
      ? "text-emerald-400"
      : "text-gray-100";

  return (
    <motion.div
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.25 }}
      className="card p-5"
    >
      <div className="flex items-center justify-between">
        <span className="text-sm text-gray-400">{label}</span>
        <span className="text-lg">{icon}</span>
      </div>
      <p className={`mt-2 text-3xl font-semibold ${toneClasses}`}>{value}</p>
    </motion.div>
  );
}
