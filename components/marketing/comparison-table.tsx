import { Check, X } from "lucide-react";
import { COMPARISON } from "@/lib/mock-data";
import { cn } from "@/lib/utils";

function Cell({ value }: { value: string | boolean }) {
  if (typeof value === "boolean") {
    return value ? (
      <Check className="mx-auto size-4 text-emerald-500" />
    ) : (
      <X className="mx-auto size-4 text-muted-foreground/40" />
    );
  }
  return <span className="text-sm">{value}</span>;
}

export function ComparisonTable() {
  return (
    <section id="compare" className="mx-auto max-w-5xl px-4 py-24 sm:px-6 lg:px-8">
      <div className="mx-auto max-w-2xl text-center">
        <h2 className="font-display text-3xl font-bold tracking-tight sm:text-4xl">
          Built to out-perform the tools you&apos;ve outgrown
        </h2>
        <p className="mt-4 text-muted-foreground">
          A side-by-side against the average AI UGC generator on the market.
        </p>
      </div>
      <div className="mt-12 overflow-hidden rounded-2xl border border-border">
        <table className="w-full border-collapse text-left">
          <thead>
            <tr className="bg-secondary/60">
              <th className="p-4 text-sm font-medium text-muted-foreground">Feature</th>
              <th className="p-4 text-center text-sm font-semibold text-primary">
                CreatorAI UGC Studio
              </th>
              <th className="p-4 text-center text-sm font-medium text-muted-foreground">
                Other tools
              </th>
            </tr>
          </thead>
          <tbody>
            {COMPARISON.map((row, i) => (
              <tr key={row.feature} className={cn(i % 2 === 1 && "bg-secondary/20")}>
                <td className="p-4 text-sm">{row.feature}</td>
                <td className="p-4 text-center">
                  <Cell value={row.us} />
                </td>
                <td className="p-4 text-center">
                  {typeof row.others === "boolean" ? (
                    <Cell value={row.others} />
                  ) : (
                    <span className="text-sm text-muted-foreground">{row.others}</span>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}
