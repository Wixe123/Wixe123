"use client";

import * as React from "react";
import { Sparkles, RefreshCw } from "lucide-react";
import { PageHeader } from "@/components/dashboard/page-header";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { Progress } from "@/components/ui/progress";
import { scoreVirality, type ViralScore } from "@/lib/ai/engine";

const DEFAULT_SCRIPT = {
  hook: "I bought this so you don't have to.",
  body: "I've tried every serum on the market and this is the first one that actually did something in under two weeks.",
  cta: "It's on sale right now — link is in my bio before it sells out.",
};

const METRICS: { key: keyof ViralScore; label: string }[] = [
  { key: "hookStrength", label: "Hook strength" },
  { key: "retentionPrediction", label: "Retention prediction" },
  { key: "watchTimePrediction", label: "Watch time prediction" },
  { key: "scrollStoppingScore", label: "Scroll-stopping score" },
  { key: "ctrPrediction", label: "CTR prediction" },
  { key: "engagementPrediction", label: "Engagement prediction" },
];

export default function OptimizerPage() {
  const [hook, setHook] = React.useState(DEFAULT_SCRIPT.hook);
  const [body, setBody] = React.useState(DEFAULT_SCRIPT.body);
  const [cta, setCta] = React.useState(DEFAULT_SCRIPT.cta);
  const [loading, setLoading] = React.useState(false);
  const [result, setResult] = React.useState<ViralScore | null>(null);

  async function analyze() {
    setLoading(true);
    const res = await scoreVirality({ hook, body, cta });
    setResult(res);
    setLoading(false);
  }

  return (
    <div>
      <PageHeader
        title="Viral Optimization Engine"
        description="Score any script for hook strength, retention, CTR, and virality before you render."
      />

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>Your script</CardTitle>
            <CardDescription>Paste or edit a script to analyze.</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div>
              <p className="mb-1.5 text-sm font-medium">Hook</p>
              <Textarea value={hook} onChange={(e) => setHook(e.target.value)} rows={2} />
            </div>
            <div>
              <p className="mb-1.5 text-sm font-medium">Body</p>
              <Textarea value={body} onChange={(e) => setBody(e.target.value)} rows={3} />
            </div>
            <div>
              <p className="mb-1.5 text-sm font-medium">Call to action</p>
              <Textarea value={cta} onChange={(e) => setCta(e.target.value)} rows={2} />
            </div>
            <Button variant="gradient" className="w-full" onClick={analyze} disabled={loading}>
              {loading ? <RefreshCw className="size-4 animate-spin" /> : <Sparkles className="size-4" />}
              {loading ? "Analyzing…" : "Analyze script"}
            </Button>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Results</CardTitle>
            <CardDescription>Predictions are directional, not guaranteed outcomes.</CardDescription>
          </CardHeader>
          <CardContent>
            {!result ? (
              <div className="flex flex-col items-center gap-2 py-16 text-center text-sm text-muted-foreground">
                <Sparkles className="size-6 text-primary" />
                Run an analysis to see your scores.
              </div>
            ) : (
              <>
                <div className="grid grid-cols-2 gap-3">
                  <div className="col-span-2 rounded-2xl border border-primary/40 bg-primary/6 p-5 text-center">
                    <p className="font-display text-4xl font-bold text-primary">{result.viralityScore}</p>
                    <p className="mt-1 text-sm text-muted-foreground">Overall virality score</p>
                  </div>
                  <div className="rounded-2xl border border-border p-4 text-center">
                    <p className="font-display text-2xl font-bold">{result.adQualityScore}</p>
                    <p className="mt-1 text-xs text-muted-foreground">Ad quality score</p>
                  </div>
                  <div className="rounded-2xl border border-border p-4 text-center">
                    <p className="font-display text-2xl font-bold">{result.watchTimePrediction}</p>
                    <p className="mt-1 text-xs text-muted-foreground">Watch time prediction</p>
                  </div>
                </div>

                <div className="mt-5 space-y-3">
                  {METRICS.map((m) => (
                    <div key={m.key}>
                      <div className="mb-1.5 flex items-center justify-between text-sm">
                        <span className="text-muted-foreground">{m.label}</span>
                        <span className="font-medium">{result[m.key] as number}</span>
                      </div>
                      <Progress value={result[m.key] as number} />
                    </div>
                  ))}
                </div>

                <div className="mt-5">
                  <p className="mb-2 text-sm font-semibold">Suggestions</p>
                  <ul className="space-y-2">
                    {result.suggestions.map((s) => (
                      <li key={s} className="flex items-start gap-2 rounded-xl border border-border p-3 text-sm text-muted-foreground">
                        <Sparkles className="mt-0.5 size-3.5 shrink-0 text-primary" />
                        {s}
                      </li>
                    ))}
                  </ul>
                </div>
              </>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
