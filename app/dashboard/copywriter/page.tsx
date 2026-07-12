"use client";

import * as React from "react";
import { toast } from "sonner";
import { Sparkles, RefreshCw, Copy } from "lucide-react";
import { PageHeader } from "@/components/dashboard/page-header";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { generateCopy, type CopyChannel } from "@/lib/ai/engine";

const CHANNELS: CopyChannel[] = [
  "TikTok caption", "Instagram caption", "Facebook caption", "Product description",
  "Email subject", "Google Ads headline", "Meta Ads primary text", "Pinterest description", "SEO title",
];

const HASHTAGS = ["#tiktokmademebuyit", "#foryoupage", "#skincaretips", "#smallbusiness", "#viral", "#musthave"];

export default function CopywriterPage() {
  const [product, setProduct] = React.useState("GlowSerum Vitamin C Serum");
  const [channel, setChannel] = React.useState<CopyChannel>("TikTok caption");
  const [loading, setLoading] = React.useState(false);
  const [results, setResults] = React.useState<string[]>([]);

  async function handleGenerate() {
    setLoading(true);
    const copy = await generateCopy(product, channel);
    setResults(copy);
    setLoading(false);
  }

  function copyText(text: string) {
    navigator.clipboard?.writeText(text);
    toast.success("Copied to clipboard");
  }

  return (
    <div>
      <PageHeader title="Copywriter" description="Generate platform-native captions, ad copy, and SEO titles." />

      <Card>
        <CardHeader>
          <CardTitle>Generate copy</CardTitle>
          <CardDescription>Pick a channel and product to write for.</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="flex flex-col gap-3 sm:flex-row">
            <Input value={product} onChange={(e) => setProduct(e.target.value)} className="sm:max-w-sm" />
            <Button variant="gradient" onClick={handleGenerate} disabled={loading}>
              {loading ? <RefreshCw className="size-4 animate-spin" /> : <Sparkles className="size-4" />}
              {loading ? "Writing…" : "Generate copy"}
            </Button>
          </div>
          <Tabs value={channel} onValueChange={(v) => setChannel(v as CopyChannel)} className="mt-5">
            <TabsList className="flex-wrap h-auto justify-start gap-1 bg-transparent p-0">
              {CHANNELS.map((c) => (
                <TabsTrigger
                  key={c}
                  value={c}
                  className="rounded-full border border-border bg-secondary/50 px-3 data-[state=active]:border-primary data-[state=active]:bg-primary/10 data-[state=active]:text-primary"
                >
                  {c}
                </TabsTrigger>
              ))}
            </TabsList>
          </Tabs>
        </CardContent>
      </Card>

      <div className="mt-6 grid grid-cols-1 gap-4 lg:grid-cols-[1fr_280px]">
        <div className="space-y-3">
          {results.length === 0 ? (
            <Card className="flex flex-col items-center gap-2 p-16 text-center text-muted-foreground">
              <Sparkles className="size-6 text-primary" />
              Generated copy for &ldquo;{channel}&rdquo; will appear here.
            </Card>
          ) : (
            results.map((r, i) => (
              <Card key={i} className="flex items-start justify-between gap-3 p-4">
                <p className="text-sm">{r}</p>
                <Button variant="ghost" size="icon-sm" onClick={() => copyText(r)}>
                  <Copy className="size-3.5" />
                </Button>
              </Card>
            ))
          )}
        </div>

        <Card className="h-fit">
          <CardHeader>
            <CardTitle>Suggested hashtags</CardTitle>
          </CardHeader>
          <CardContent className="flex flex-wrap gap-2">
            {HASHTAGS.map((h) => (
              <button
                key={h}
                onClick={() => copyText(h)}
                className="rounded-full border border-border bg-secondary/50 px-2.5 py-1 text-xs text-muted-foreground hover:text-foreground"
              >
                {h}
              </button>
            ))}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
