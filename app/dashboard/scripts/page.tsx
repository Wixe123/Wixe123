"use client";

import * as React from "react";
import { toast } from "sonner";
import { Sparkles, RefreshCw, Copy } from "lucide-react";
import { PageHeader } from "@/components/dashboard/page-header";
import { ScriptCard } from "@/components/wizard/script-card";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectTrigger, SelectValue, SelectContent, SelectItem } from "@/components/ui/select";
import { Badge } from "@/components/ui/badge";
import { AUDIENCES, PLATFORMS, OBJECTIVES, HOOKS, TOP_HOOKS } from "@/lib/mock-data";
import { generateScripts, type ProductInfo, type Script } from "@/lib/ai/engine";

const DEMO_PRODUCT: ProductInfo = {
  title: "GlowSerum Vitamin C Brightening Serum",
  brand: "Loop Skincare",
  price: "$34.00",
  description: "A lightweight vitamin C serum that visibly brightens skin tone.",
  features: ["20% Vitamin C complex", "Hyaluronic acid"],
  benefits: ["Brighter, more even skin tone", "Non-greasy, fast absorption"],
  colors: ["Amber"],
  rating: 4.7,
  reviewCount: 2318,
  targetAudience: ["Beauty enthusiasts"],
  competitors: ["The Ordinary"],
  sourceType: "text",
};

export default function ScriptsPage() {
  const [productName, setProductName] = React.useState(DEMO_PRODUCT.title);
  const [audience, setAudience] = React.useState(AUDIENCES[0]);
  const [platform, setPlatform] = React.useState(PLATFORMS[0].id);
  const [objective, setObjective] = React.useState(OBJECTIVES[0]);
  const [scripts, setScripts] = React.useState<Script[]>([]);
  const [loading, setLoading] = React.useState(false);
  const [selectedId, setSelectedId] = React.useState<string | null>(null);

  async function handleGenerate() {
    setLoading(true);
    const result = await generateScripts({
      product: { ...DEMO_PRODUCT, title: productName || DEMO_PRODUCT.title },
      audience,
      platform,
      objective,
    });
    setScripts(result);
    setSelectedId(result[0]?.id ?? null);
    setLoading(false);
  }

  return (
    <div>
      <PageHeader title="Scripts" description="Generate marketing-psychology scripts for any product." />

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-[340px_1fr]">
        <Card className="h-fit">
          <CardHeader>
            <CardTitle>Script settings</CardTitle>
            <CardDescription>We&apos;ll build 5 variants from these inputs.</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-1.5">
              <Label>Product</Label>
              <Input value={productName} onChange={(e) => setProductName(e.target.value)} />
            </div>
            <div className="space-y-1.5">
              <Label>Audience</Label>
              <Select value={audience} onValueChange={setAudience}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  {AUDIENCES.map((a) => <SelectItem key={a} value={a}>{a}</SelectItem>)}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-1.5">
              <Label>Platform</Label>
              <Select value={platform} onValueChange={setPlatform}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  {PLATFORMS.map((p) => <SelectItem key={p.id} value={p.id}>{p.name}</SelectItem>)}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-1.5">
              <Label>Objective</Label>
              <Select value={objective} onValueChange={setObjective}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  {OBJECTIVES.map((o) => <SelectItem key={o} value={o}>{o}</SelectItem>)}
                </SelectContent>
              </Select>
            </div>
            <Button variant="gradient" className="w-full" onClick={handleGenerate} disabled={loading}>
              {loading ? <RefreshCw className="size-4 animate-spin" /> : <Sparkles className="size-4" />}
              {loading ? "Generating…" : "Generate 5 scripts"}
            </Button>
          </CardContent>
        </Card>

        <div>
          {scripts.length === 0 ? (
            <Card>
              <CardContent className="flex flex-col items-center gap-2 p-16 text-center text-muted-foreground">
                <Sparkles className="size-6 text-primary" />
                Generate scripts to see them here — each comes with a quality score and psychology tags.
              </CardContent>
            </Card>
          ) : (
            <div className="space-y-3">
              {scripts.map((s) => (
                <ScriptCard key={s.id} script={s} selected={selectedId === s.id} onSelect={() => setSelectedId(s.id)} />
              ))}
            </div>
          )}

          <Card className="mt-6">
            <CardHeader>
              <CardTitle>Hook library</CardTitle>
              <CardDescription>Top performing hooks across your account.</CardDescription>
            </CardHeader>
            <CardContent className="grid grid-cols-1 gap-2 sm:grid-cols-2">
              {HOOKS.map((h) => {
                const stats = TOP_HOOKS.find((t) => t.hook === h);
                return (
                  <button
                    key={h}
                    onClick={() => {
                      navigator.clipboard?.writeText(h);
                      toast.success("Hook copied to clipboard");
                    }}
                    className="group flex items-start justify-between gap-2 rounded-xl border border-border p-3 text-left text-sm hover:bg-secondary/60"
                  >
                    <span>&ldquo;{h}&rdquo;</span>
                    <span className="flex shrink-0 items-center gap-1.5">
                      {stats && <Badge variant="secondary">{stats.score}</Badge>}
                      <Copy className="size-3.5 text-muted-foreground opacity-0 group-hover:opacity-100" />
                    </span>
                  </button>
                );
              })}
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  );
}
