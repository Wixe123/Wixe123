import { Card } from "@/components/ui/card";
import { cn } from "@/lib/utils";
import { ArrowDownRight, ArrowUpRight, type LucideIcon } from "lucide-react";

export function StatCard({
  label,
  value,
  icon: Icon,
  trend,
  trendLabel,
  className,
}: {
  label: string;
  value: string;
  icon: LucideIcon;
  trend?: number;
  trendLabel?: string;
  className?: string;
}) {
  return (
    <Card className={cn("p-5", className)}>
      <div className="flex items-center justify-between">
        <span className="text-sm font-medium text-muted-foreground">{label}</span>
        <span className="flex size-8 items-center justify-center rounded-lg bg-primary/12 text-primary">
          <Icon className="size-4" />
        </span>
      </div>
      <p className="mt-3 font-display text-2xl font-bold tracking-tight">{value}</p>
      {trend !== undefined && (
        <p
          className={cn(
            "mt-1.5 flex items-center gap-1 text-xs font-medium",
            trend >= 0 ? "text-emerald-500" : "text-destructive"
          )}
        >
          {trend >= 0 ? <ArrowUpRight className="size-3.5" /> : <ArrowDownRight className="size-3.5" />}
          {Math.abs(trend)}% {trendLabel ?? "vs last week"}
        </p>
      )}
    </Card>
  );
}
