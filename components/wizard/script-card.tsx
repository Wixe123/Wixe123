import { Check } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { cn } from "@/lib/utils";
import type { Script } from "@/lib/ai/engine";

function scoreColor(score: number) {
  if (score >= 90) return "text-emerald-500";
  if (score >= 75) return "text-amber-500";
  return "text-muted-foreground";
}

export function ScriptCard({
  script,
  selected,
  onSelect,
}: {
  script: Script;
  selected: boolean;
  onSelect: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onSelect}
      className={cn(
        "relative w-full rounded-2xl border p-5 text-left transition-all",
        selected
          ? "border-primary bg-primary/6 shadow-[0_0_0_1px_var(--primary)]"
          : "border-border bg-card hover:border-primary/40"
      )}
    >
      {selected && (
        <span className="absolute top-4 right-4 flex size-5 items-center justify-center rounded-full bg-primary text-primary-foreground">
          <Check className="size-3" />
        </span>
      )}
      <div className="flex items-center gap-2 pr-8">
        <span className={cn("font-display text-xl font-bold", scoreColor(script.qualityScore))}>
          {script.qualityScore}
        </span>
        <span className="text-xs text-muted-foreground">quality score</span>
        <Badge variant="secondary" className="ml-auto sm:ml-2">{script.tone}</Badge>
        <span className="text-xs text-muted-foreground">{script.durationSec}s</span>
      </div>
      <p className="mt-3 font-semibold">&ldquo;{script.hook}&rdquo;</p>
      <p className="mt-1.5 text-sm text-muted-foreground">{script.body}</p>
      <p className="mt-1.5 text-sm font-medium text-primary">{script.cta}</p>
      <div className="mt-3 flex flex-wrap gap-1.5">
        {script.tags.map((t) => (
          <Badge key={t} variant="outline">{t}</Badge>
        ))}
      </div>
    </button>
  );
}
