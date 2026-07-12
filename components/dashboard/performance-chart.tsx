"use client";

import {
  AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,
} from "recharts";
import { WEEKLY_PERFORMANCE } from "@/lib/mock-data";

export function PerformanceChart() {
  return (
    <div className="h-64 w-full">
      <ResponsiveContainer width="100%" height="100%">
        <AreaChart data={WEEKLY_PERFORMANCE} margin={{ top: 8, right: 8, left: -20, bottom: 0 }}>
          <defs>
            <linearGradient id="videosGradient" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="var(--gradient-1)" stopOpacity={0.35} />
              <stop offset="100%" stopColor="var(--gradient-1)" stopOpacity={0} />
            </linearGradient>
          </defs>
          <CartesianGrid strokeDasharray="3 3" stroke="var(--border)" vertical={false} />
          <XAxis dataKey="day" stroke="var(--muted-foreground)" fontSize={12} tickLine={false} axisLine={false} />
          <YAxis stroke="var(--muted-foreground)" fontSize={12} tickLine={false} axisLine={false} />
          <Tooltip
            contentStyle={{
              background: "var(--popover)",
              border: "1px solid var(--border)",
              borderRadius: 12,
              fontSize: 12,
              color: "var(--popover-foreground)",
            }}
          />
          <Area
            type="monotone"
            dataKey="videos"
            stroke="var(--primary)"
            strokeWidth={2.5}
            fill="url(#videosGradient)"
            name="Videos created"
          />
        </AreaChart>
      </ResponsiveContainer>
    </div>
  );
}
