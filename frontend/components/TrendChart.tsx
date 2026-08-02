"use client";

import { useMemo, useState } from "react";
import type { TrendPoint } from "@/lib/types";

const WIDTH = 640;
const HEIGHT = 200;
const PAD = { top: 16, right: 8, bottom: 8, left: 8 };

function formatValue(metric: "views" | "watch_time_minutes", value: number): string {
  return metric === "views" ? value.toLocaleString() : `${(value / 60).toFixed(1)}h`;
}

export default function TrendChart({
  data,
  metric,
}: {
  data: TrendPoint[];
  metric: "views" | "watch_time_minutes";
}) {
  const [hoverIdx, setHoverIdx] = useState<number | null>(null);

  const { points, path, areaPath } = useMemo(() => {
    if (data.length === 0) return { points: [] as { x: number; y: number; value: number; date: string }[], path: "", areaPath: "" };
    const values = data.map((d) => d[metric]);
    const maxY = Math.max(...values, 1);
    const innerW = WIDTH - PAD.left - PAD.right;
    const innerH = HEIGHT - PAD.top - PAD.bottom;
    const stepX = data.length > 1 ? innerW / (data.length - 1) : 0;
    const points = data.map((d, i) => ({
      x: PAD.left + i * stepX,
      y: PAD.top + innerH - (d[metric] / maxY) * innerH,
      value: d[metric],
      date: d.date,
    }));
    const linePath = points.map((p, i) => `${i === 0 ? "M" : "L"}${p.x},${p.y}`).join(" ");
    const areaPath = `${linePath} L${points[points.length - 1].x},${PAD.top + innerH} L${points[0].x},${PAD.top + innerH} Z`;
    return { points, path: linePath, areaPath };
  }, [data, metric]);

  if (data.length === 0) {
    return <p className="text-sm text-gray-500">No trend data for this period yet.</p>;
  }

  const hovered = hoverIdx !== null ? points[hoverIdx] : null;

  return (
    <div className="relative">
      <svg
        viewBox={`0 0 ${WIDTH} ${HEIGHT}`}
        className="w-full touch-none"
        role="img"
        aria-label={`${metric === "views" ? "Views" : "Watch time"} over time`}
        onMouseLeave={() => setHoverIdx(null)}
        onMouseMove={(e) => {
          if (points.length === 0) return;
          const rect = e.currentTarget.getBoundingClientRect();
          const relX = ((e.clientX - rect.left) / rect.width) * WIDTH;
          let closest = 0;
          let closestDist = Infinity;
          points.forEach((p, i) => {
            const dist = Math.abs(p.x - relX);
            if (dist < closestDist) {
              closestDist = dist;
              closest = i;
            }
          });
          setHoverIdx(closest);
        }}
      >
        {[0.33, 0.66].map((f) => (
          <line
            key={f}
            x1={PAD.left}
            x2={WIDTH - PAD.right}
            y1={PAD.top + (HEIGHT - PAD.top - PAD.bottom) * f}
            y2={PAD.top + (HEIGHT - PAD.top - PAD.bottom) * f}
            stroke="currentColor"
            className="text-white/[0.06]"
            strokeWidth={1}
          />
        ))}
        <defs>
          <linearGradient id={`trendGradient-${metric}`} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="#e2c789" stopOpacity={0.45} />
            <stop offset="100%" stopColor="#e2c789" stopOpacity={0} />
          </linearGradient>
        </defs>
        <path d={areaPath} fill={`url(#trendGradient-${metric})`} />
        <path d={path} fill="none" stroke="#e2c789" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" />
        {hovered && (
          <>
            <line
              x1={hovered.x}
              x2={hovered.x}
              y1={PAD.top}
              y2={HEIGHT - PAD.bottom}
              stroke="currentColor"
              className="text-white/20"
              strokeWidth={1}
            />
            <circle cx={hovered.x} cy={hovered.y} r={4} fill="#e2c789" stroke="#0e0e10" strokeWidth={2} />
          </>
        )}
      </svg>
      {hovered && (
        <div
          className="pointer-events-none absolute -translate-x-1/2 -translate-y-[calc(100%+8px)] rounded-md border border-white/10 bg-base-900 px-2.5 py-1.5 text-xs shadow-lg"
          style={{ left: `${(hovered.x / WIDTH) * 100}%`, top: `${(hovered.y / HEIGHT) * 100}%` }}
        >
          <p className="font-medium text-gray-100">{formatValue(metric, hovered.value)}</p>
          <p className="text-gray-500">
            {new Date(hovered.date).toLocaleDateString(undefined, { month: "short", day: "numeric" })}
          </p>
        </div>
      )}
    </div>
  );
}
