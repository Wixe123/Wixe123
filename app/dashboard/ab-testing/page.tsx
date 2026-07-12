"use client";

import * as React from "react";
import { Sparkles, RefreshCw, Trophy } from "lucide-react";
import { PageHeader } from "@/components/dashboard/page-header";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { generateABVariants, type ABVariant } from "@/lib/ai/engine";
import { cn } from "@/lib/utils";

export default function ABTestingPage() {
  const [product, setProduct] = React.useState("GlowSerum Vitamin C Serum");
  const [loading, setLoading] = React.useState(false);
  const [variants, setVariants] = React.useState<ABVariant[]>([]);

  async function handleGenerate() {
    setLoading(true);
    const result = await generateABVariants(product);
    setVariants(result);
    setLoading(false);
  }

  const winnerId = variants.length
    ? variants.reduce((a, b) => (b.predictedCtr > a.predictedCtr ? b : a)).id
    : null;

  return (
    <div>
      <PageHeader title="A/B Testing" description="Generate 3 variants with different hooks, voices, and CTAs." />

      <div className="mb-6 flex flex-col gap-3 sm:flex-row">
        <Input value={product} onChange={(e) => setProduct(e.target.value)} className="sm:max-w-sm" />
        <Button variant="gradient" onClick={handleGenerate} disabled={loading}>
          {loading ? <RefreshCw className="size-4 animate-spin" /> : <Sparkles className="size-4" />}
          {loading ? "Generating variants…" : "Generate A/B/C variants"}
        </Button>
      </div>

      {variants.length === 0 ? (
        <Card className="flex flex-col items-center gap-2 p-16 text-center text-muted-foreground">
          <Sparkles className="size-6 text-primary" />
          Generate variants to compare hooks, voices, and CTAs side by side.
        </Card>
      ) : (
        <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
          {variants.map((v) => (
            <Card key={v.id} className={cn(v.id === winnerId && "border-primary shadow-[0_0_0_1px_var(--primary)]")}>
              <CardHeader className="flex-row items-center justify-between space-y-0">
                <CardTitle className="flex items-center gap-2">
                  Variant {v.label}
                  {v.id === winnerId && <Trophy className="size-4 text-amber-500" />}
                </CardTitle>
                {v.id === winnerId && <Badge variant="success">Predicted winner</Badge>}
              </CardHeader>
              <CardContent className="space-y-3 text-sm">
                <div>
                  <p className="text-xs font-semibold text-muted-foreground uppercase">Hook</p>
                  <p className="mt-0.5">&ldquo;{v.hook}&rdquo;</p>
                </div>
                <div>
                  <p className="text-xs font-semibold text-muted-foreground uppercase">Voice</p>
                  <p className="mt-0.5">{v.voice}</p>
                </div>
                <div>
                  <p className="text-xs font-semibold text-muted-foreground uppercase">Background</p>
                  <p className="mt-0.5">{v.background}</p>
                </div>
                <div>
                  <p className="text-xs font-semibold text-muted-foreground uppercase">CTA</p>
                  <p className="mt-0.5">{v.cta}</p>
                </div>
                <div className="flex items-center justify-between rounded-xl border border-border p-3">
                  <span className="text-xs text-muted-foreground">Predicted CTR</span>
                  <span className="font-display text-lg font-bold text-primary">{v.predictedCtr.toFixed(1)}%</span>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
