import { Check } from "lucide-react";
import { cn } from "@/lib/utils";

export function SelectTile({
  selected,
  onClick,
  icon,
  label,
  sublabel,
  className,
}: {
  selected: boolean;
  onClick: () => void;
  icon?: React.ReactNode;
  label: string;
  sublabel?: string;
  className?: string;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={cn(
        "group relative flex flex-col items-start gap-1 rounded-2xl border p-4 text-left transition-all",
        selected
          ? "border-primary bg-primary/8 shadow-[0_0_0_1px_var(--primary)]"
          : "border-border bg-card hover:border-primary/40 hover:bg-secondary/60",
        className
      )}
    >
      {selected && (
        <span className="absolute top-3 right-3 flex size-5 items-center justify-center rounded-full bg-primary text-primary-foreground">
          <Check className="size-3" />
        </span>
      )}
      {icon}
      <span className="font-medium">{label}</span>
      {sublabel && <span className="text-xs text-muted-foreground">{sublabel}</span>}
    </button>
  );
}
