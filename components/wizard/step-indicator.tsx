import { Check } from "lucide-react";
import { cn } from "@/lib/utils";

export function StepIndicator({
  steps,
  current,
}: {
  steps: string[];
  current: number;
}) {
  return (
    <div className="mb-8 flex items-center gap-1 overflow-x-auto no-scrollbar sm:gap-2">
      {steps.map((label, i) => {
        const state = i < current ? "done" : i === current ? "active" : "pending";
        return (
          <div key={label} className="flex shrink-0 items-center gap-1 sm:gap-2">
            <div className="flex items-center gap-2">
              <span
                className={cn(
                  "flex size-6 shrink-0 items-center justify-center rounded-full text-[11px] font-semibold transition-colors",
                  state === "done" && "bg-primary text-primary-foreground",
                  state === "active" && "bg-primary/15 text-primary ring-2 ring-primary",
                  state === "pending" && "bg-secondary text-muted-foreground"
                )}
              >
                {state === "done" ? <Check className="size-3.5" /> : i + 1}
              </span>
              <span
                className={cn(
                  "text-xs font-medium whitespace-nowrap",
                  state === "pending" ? "text-muted-foreground" : "text-foreground"
                )}
              >
                {label}
              </span>
            </div>
            {i < steps.length - 1 && <div className="mx-1 h-px w-6 bg-border sm:w-10" />}
          </div>
        );
      })}
    </div>
  );
}
