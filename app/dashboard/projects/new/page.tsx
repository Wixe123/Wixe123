"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import {
  Image as ImageIcon, Video, Link2, ShoppingBag, Globe, FileText, File as FileIcon,
  Sparkles, RefreshCw, Play, Download, ArrowLeft, ArrowRight, Timer, Volume2,
} from "lucide-react";
import { PageHeader } from "@/components/dashboard/page-header";
import { StepIndicator } from "@/components/wizard/step-indicator";
import { SelectTile } from "@/components/wizard/select-tile";
import { ProductCard } from "@/components/wizard/product-card";
import { ScriptCard } from "@/components/wizard/script-card";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Progress } from "@/components/ui/progress";
import { Badge } from "@/components/ui/badge";
import {
  Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter,
} from "@/components/ui/dialog";
import { AUDIENCES, PLATFORMS, OBJECTIVES, AVATARS, VOICES } from "@/lib/mock-data";
import { scoreVirality, generateVoicePreview, type ProductInfo, type Script, type ViralScore } from "@/lib/ai/engine";
import { cn, sleep } from "@/lib/utils";

const STEPS = ["Product", "Audience", "Platform", "Objective", "Scripts", "Cast", "Render"];

const SOURCES: { id: ProductInfo["sourceType"]; label: string; icon: React.ElementType; placeholder: string; kind: "text" | "file" }[] = [
  { id: "shopify", label: "Shopify link", icon: ShoppingBag, placeholder: "https://yourstore.com/products/...", kind: "text" },
  { id: "amazon", label: "Amazon link", icon: Link2, placeholder: "https://amazon.com/dp/...", kind: "text" },
  { id: "website", label: "Website URL", icon: Globe, placeholder: "https://yourbrand.com", kind: "text" },
  { id: "text", label: "Description", icon: FileText, placeholder: "Describe your product…", kind: "text" },
  { id: "image", label: "Upload images", icon: ImageIcon, placeholder: "", kind: "file" },
  { id: "video", label: "Upload video", icon: Video, placeholder: "", kind: "file" },
  { id: "pdf", label: "Upload PDF", icon: FileIcon, placeholder: "", kind: "file" },
];

export default function NewProjectPage() {
  const router = useRouter();
  const [step, setStep] = React.useState(0);
  const [elapsed, setElapsed] = React.useState(0);

  // Step 0 — product
  const [source, setSource] = React.useState(SOURCES[0]);
  const [inputValue, setInputValue] = React.useState("");
  const [fileName, setFileName] = React.useState("");
  const [product, setProduct] = React.useState<ProductInfo | null>(null);
  const [scraping, setScraping] = React.useState(false);

  // Step 1-3
  const [audience, setAudience] = React.useState<string | null>(null);
  const [platform, setPlatform] = React.useState<string | null>(null);
  const [objective, setObjective] = React.useState<string | null>(null);

  // Step 4 — scripts
  const [scripts, setScripts] = React.useState<Script[]>([]);
  const [generatingScripts, setGeneratingScripts] = React.useState(false);
  const [selectedScriptId, setSelectedScriptId] = React.useState<string | null>(null);

  // Step 5 — cast
  const [avatarId, setAvatarId] = React.useState<string | null>(null);
  const [voiceId, setVoiceId] = React.useState<string | null>(null);
  const [previewingVoice, setPreviewingVoice] = React.useState<string | null>(null);

  // Step 6 — render
  const [rendering, setRendering] = React.useState(false);
  const [renderProgress, setRenderProgress] = React.useState(0);
  const [rendered, setRendered] = React.useState(false);
  const [viralScore, setViralScore] = React.useState<ViralScore | null>(null);
  const [exportOpen, setExportOpen] = React.useState(false);

  React.useEffect(() => {
    const t = setInterval(() => setElapsed((e) => e + 1), 1000);
    return () => clearInterval(t);
  }, []);

  const selectedScript = scripts.find((s) => s.id === selectedScriptId) ?? null;
  const selectedAvatar = AVATARS.find((a) => a.id === avatarId) ?? null;
  const selectedVoice = VOICES.find((v) => v.id === voiceId) ?? null;
  const compatibleAvatars = AVATARS.slice(0, 12);

  async function handleScrape() {
    setScraping(true);
    try {
      const res = await fetch("/api/scrape-product", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ input: inputValue || fileName || source.id, sourceType: source.id }),
      });
      const data = await res.json();
      setProduct(data.product);
      toast.success("Product details scraped");
    } catch {
      toast.error("Couldn't scrape product — try again");
    } finally {
      setScraping(false);
    }
  }

  async function handleGenerateScripts() {
    if (!product || !audience || !platform || !objective) return;
    setGeneratingScripts(true);
    try {
      const res = await fetch("/api/generate-scripts", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ product, audience, platform, objective }),
      });
      const data = await res.json();
      setScripts(data.scripts);
      setSelectedScriptId(data.scripts[0]?.id ?? null);
    } catch {
      toast.error("Script generation failed — try again");
    } finally {
      setGeneratingScripts(false);
    }
  }

  async function handlePreviewVoice(id: string) {
    setPreviewingVoice(id);
    await generateVoicePreview(id);
    toast.message("Playing voice preview…");
    await sleep(1200);
    setPreviewingVoice(null);
  }

  async function handleRender() {
    if (!selectedScript) return;
    setRendering(true);
    setRenderProgress(0);
    const interval = setInterval(() => {
      setRenderProgress((p) => Math.min(96, p + Math.random() * 14));
    }, 260);
    const score = await scoreVirality(selectedScript);
    await sleep(2400);
    clearInterval(interval);
    setRenderProgress(100);
    setViralScore(score);
    await sleep(300);
    setRendering(false);
    setRendered(true);
    toast.success("Your ad is ready");
  }

  function canContinue() {
    switch (step) {
      case 0: return Boolean(product);
      case 1: return Boolean(audience);
      case 2: return Boolean(platform);
      case 3: return Boolean(objective);
      case 4: return Boolean(selectedScript);
      case 5: return Boolean(avatarId && voiceId);
      default: return true;
    }
  }

  function goNext() {
    if (step === 3 && scripts.length === 0) handleGenerateScripts();
    setStep((s) => Math.min(STEPS.length - 1, s + 1));
  }

  const minutes = String(Math.floor(elapsed / 60)).padStart(2, "0");
  const seconds = String(elapsed % 60).padStart(2, "0");

  return (
    <div>
      <PageHeader
        title="New project"
        description="Go from product to finished ad in under 3 minutes."
        actions={
          <Badge variant={elapsed < 180 ? "success" : "warning"} className="gap-1.5 px-3 py-1.5">
            <Timer className="size-3.5" /> {minutes}:{seconds}
          </Badge>
        }
      />

      <StepIndicator steps={STEPS} current={step} />

      <Card>
        <CardContent className="p-6">
          {step === 0 && (
            <div>
              <h2 className="font-display text-lg font-semibold">Upload your product</h2>
              <p className="mt-1 text-sm text-muted-foreground">
                Paste a link or upload a file — we&apos;ll automatically scrape the title, features, price, reviews, and brand.
              </p>
              <div className="mt-5 grid grid-cols-2 gap-2 sm:grid-cols-4">
                {SOURCES.map((s) => (
                  <button
                    key={s.id}
                    onClick={() => {
                      setSource(s);
                      setProduct(null);
                    }}
                    className={cn(
                      "flex flex-col items-center gap-1.5 rounded-xl border p-3 text-xs font-medium transition-colors",
                      source.id === s.id
                        ? "border-primary bg-primary/8 text-primary"
                        : "border-border text-muted-foreground hover:bg-secondary"
                    )}
                  >
                    <s.icon className="size-4" />
                    {s.label}
                  </button>
                ))}
              </div>

              <div className="mt-5">
                {source.kind === "text" ? (
                  source.id === "text" ? (
                    <Textarea
                      value={inputValue}
                      onChange={(e) => setInputValue(e.target.value)}
                      placeholder={source.placeholder}
                      rows={4}
                    />
                  ) : (
                    <Input
                      value={inputValue}
                      onChange={(e) => setInputValue(e.target.value)}
                      placeholder={source.placeholder}
                    />
                  )
                ) : (
                  <label className="flex cursor-pointer flex-col items-center justify-center gap-2 rounded-xl border border-dashed border-border p-10 text-center text-sm text-muted-foreground hover:bg-secondary/50">
                    <source.icon className="size-6" />
                    {fileName || `Click to upload a ${source.label.toLowerCase()}`}
                    <input
                      type="file"
                      className="hidden"
                      onChange={(e) => setFileName(e.target.files?.[0]?.name ?? "")}
                    />
                  </label>
                )}
                <Button
                  className="mt-4"
                  variant="gradient"
                  disabled={scraping || (source.kind === "text" ? !inputValue : !fileName)}
                  onClick={handleScrape}
                >
                  {scraping ? <RefreshCw className="size-4 animate-spin" /> : <Sparkles className="size-4" />}
                  {scraping ? "Scraping product…" : "Scrape product details"}
                </Button>
              </div>

              {product && (
                <div className="mt-6">
                  <ProductCard product={product} />
                </div>
              )}
            </div>
          )}

          {step === 1 && (
            <div>
              <h2 className="font-display text-lg font-semibold">Choose your audience</h2>
              <p className="mt-1 text-sm text-muted-foreground">Who is this ad speaking to?</p>
              <div className="mt-5 grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
                {AUDIENCES.map((a) => (
                  <SelectTile key={a} label={a} selected={audience === a} onClick={() => setAudience(a)} />
                ))}
              </div>
            </div>
          )}

          {step === 2 && (
            <div>
              <h2 className="font-display text-lg font-semibold">Choose your platform</h2>
              <p className="mt-1 text-sm text-muted-foreground">We&apos;ll frame and format the export for this platform.</p>
              <div className="mt-5 grid grid-cols-2 gap-3 sm:grid-cols-4">
                {PLATFORMS.map((p) => (
                  <SelectTile
                    key={p.id}
                    label={p.name}
                    sublabel={p.ratio}
                    selected={platform === p.id}
                    onClick={() => setPlatform(p.id)}
                  />
                ))}
              </div>
            </div>
          )}

          {step === 3 && (
            <div>
              <h2 className="font-display text-lg font-semibold">Choose your objective</h2>
              <p className="mt-1 text-sm text-muted-foreground">This shapes the CTA and urgency in your script.</p>
              <div className="mt-5 grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
                {OBJECTIVES.map((o) => (
                  <SelectTile key={o} label={o} selected={objective === o} onClick={() => setObjective(o)} />
                ))}
              </div>
            </div>
          )}

          {step === 4 && (
            <div>
              <div className="flex flex-wrap items-center justify-between gap-3">
                <div>
                  <h2 className="font-display text-lg font-semibold">Pick your script</h2>
                  <p className="mt-1 text-sm text-muted-foreground">
                    5 scripts generated with proven marketing psychology, scored for quality.
                  </p>
                </div>
                <Button variant="outline" size="sm" onClick={handleGenerateScripts} disabled={generatingScripts}>
                  <RefreshCw className={cn("size-3.5", generatingScripts && "animate-spin")} /> Regenerate
                </Button>
              </div>

              {generatingScripts && scripts.length === 0 ? (
                <div className="mt-8 flex flex-col items-center gap-3 py-10 text-center text-sm text-muted-foreground">
                  <RefreshCw className="size-5 animate-spin text-primary" />
                  Writing 5 scripts using hook, pain point, story, and CTA psychology…
                </div>
              ) : (
                <div className="mt-5 space-y-3">
                  {scripts.map((s) => (
                    <ScriptCard
                      key={s.id}
                      script={s}
                      selected={selectedScriptId === s.id}
                      onSelect={() => setSelectedScriptId(s.id)}
                    />
                  ))}
                </div>
              )}
            </div>
          )}

          {step === 5 && (
            <div>
              <h2 className="font-display text-lg font-semibold">Choose your avatar & voice</h2>
              <p className="mt-1 text-sm text-muted-foreground">
                Browse the full library in Avatars and Voices — here&apos;s a quick set to get started.
              </p>

              <p className="mt-5 mb-2 text-sm font-medium">Avatar</p>
              <div className="grid grid-cols-3 gap-3 sm:grid-cols-4 lg:grid-cols-6">
                {compatibleAvatars.map((a) => (
                  <button
                    key={a.id}
                    onClick={() => setAvatarId(a.id)}
                    className={cn(
                      "relative flex flex-col items-center gap-1.5 rounded-xl border p-3 transition-all",
                      avatarId === a.id ? "border-primary bg-primary/8" : "border-border hover:bg-secondary/60"
                    )}
                  >
                    <span
                      className={cn(
                        "flex size-12 items-center justify-center rounded-full bg-gradient-to-br text-xl text-white",
                        a.gradient
                      )}
                    >
                      {a.emoji}
                    </span>
                    <span className="text-xs font-medium">{a.name}</span>
                  </button>
                ))}
              </div>

              <p className="mt-6 mb-2 text-sm font-medium">Voice</p>
              <div className="grid grid-cols-1 gap-2 sm:grid-cols-2">
                {VOICES.map((v) => (
                  <div
                    key={v.id}
                    onClick={() => setVoiceId(v.id)}
                    className={cn(
                      "flex cursor-pointer items-center gap-3 rounded-xl border p-3 transition-all",
                      voiceId === v.id ? "border-primary bg-primary/8" : "border-border hover:bg-secondary/60"
                    )}
                  >
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        handlePreviewVoice(v.id);
                      }}
                      className="flex size-9 shrink-0 items-center justify-center rounded-full bg-secondary"
                    >
                      {previewingVoice === v.id ? (
                        <Volume2 className="size-4 animate-pulse text-primary" />
                      ) : (
                        <Play className="size-3.5" />
                      )}
                    </button>
                    <div className="min-w-0 flex-1">
                      <p className="text-sm font-medium">
                        {v.name} <span className="text-muted-foreground">· {v.accent} {v.language}</span>
                      </p>
                      <p className="truncate text-xs text-muted-foreground">{v.emotion} — &ldquo;{v.sampleLine}&rdquo;</p>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {step === 6 && (
            <div>
              {!rendered ? (
                <div className="flex flex-col items-center py-10 text-center">
                  <h2 className="font-display text-lg font-semibold">Ready to render</h2>
                  <p className="mt-1 max-w-md text-sm text-muted-foreground">
                    {selectedAvatar?.name} will deliver your script in {selectedVoice?.name}&apos;s voice, formatted for{" "}
                    {PLATFORMS.find((p) => p.id === platform)?.name}.
                  </p>
                  {rendering ? (
                    <div className="mt-8 w-full max-w-sm">
                      <Progress value={renderProgress} />
                      <p className="mt-2 text-xs text-muted-foreground">
                        Rendering avatar, syncing lip movement, adding captions… {Math.round(renderProgress)}%
                      </p>
                    </div>
                  ) : (
                    <Button variant="gradient" size="lg" className="mt-8" onClick={handleRender}>
                      <Sparkles className="size-4" /> Generate video
                    </Button>
                  )}
                </div>
              ) : (
                <div className="grid grid-cols-1 gap-6 lg:grid-cols-[280px_1fr]">
                  <div>
                    <div
                      className={cn(
                        "relative flex aspect-9/16 flex-col items-center justify-center overflow-hidden rounded-2xl bg-gradient-to-br text-6xl text-white",
                        selectedAvatar?.gradient
                      )}
                    >
                      {selectedAvatar?.emoji}
                      <div className="absolute inset-x-0 bottom-0 bg-gradient-to-t from-black/70 to-transparent p-3 text-left">
                        <p className="text-xs font-medium text-white">&ldquo;{selectedScript?.hook}&rdquo;</p>
                      </div>
                    </div>
                    <div className="mt-3 flex gap-2">
                      <Button variant="gradient" className="flex-1" onClick={() => setExportOpen(true)}>
                        <Download className="size-4" /> Export
                      </Button>
                    </div>
                  </div>

                  <div>
                    <h2 className="font-display text-lg font-semibold">Your ad is ready</h2>
                    <p className="mt-1 text-sm text-muted-foreground">
                      Viral optimization results — see the full breakdown in Viral Optimizer.
                    </p>
                    {viralScore && (
                      <>
                        <div className="mt-4 grid grid-cols-2 gap-3 sm:grid-cols-4">
                          {[
                            { label: "Virality score", value: viralScore.viralityScore },
                            { label: "Ad quality", value: viralScore.adQualityScore },
                            { label: "Hook strength", value: viralScore.hookStrength },
                            { label: "CTR prediction", value: viralScore.ctrPrediction },
                          ].map((m) => (
                            <div key={m.label} className="rounded-xl border border-border p-3 text-center">
                              <p className="font-display text-2xl font-bold text-primary">{m.value}</p>
                              <p className="mt-0.5 text-xs text-muted-foreground">{m.label}</p>
                            </div>
                          ))}
                        </div>
                        <div className="mt-5">
                          <p className="mb-2 text-sm font-medium">Suggestions to improve further</p>
                          <ul className="space-y-2">
                            {viralScore.suggestions.map((s) => (
                              <li key={s} className="flex items-start gap-2 text-sm text-muted-foreground">
                                <Sparkles className="mt-0.5 size-3.5 shrink-0 text-primary" />
                                {s}
                              </li>
                            ))}
                          </ul>
                        </div>
                      </>
                    )}
                    <Button
                      variant="outline"
                      className="mt-6"
                      onClick={() => router.push("/dashboard/projects")}
                    >
                      Go to projects
                    </Button>
                  </div>
                </div>
              )}
            </div>
          )}
        </CardContent>
      </Card>

      {step < 6 && (
        <div className="mt-6 flex items-center justify-between">
          <Button variant="ghost" disabled={step === 0} onClick={() => setStep((s) => Math.max(0, s - 1))}>
            <ArrowLeft className="size-4" /> Back
          </Button>
          <Button variant="gradient" disabled={!canContinue()} onClick={goNext}>
            Continue <ArrowRight className="size-4" />
          </Button>
        </div>
      )}

      <Dialog open={exportOpen} onOpenChange={setExportOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Export video</DialogTitle>
          </DialogHeader>
          <Tabs defaultValue="1080p">
            <TabsList>
              <TabsTrigger value="1080p">1080p</TabsTrigger>
              <TabsTrigger value="2k">2K</TabsTrigger>
              <TabsTrigger value="4k">4K</TabsTrigger>
            </TabsList>
          </Tabs>
          <div className="grid grid-cols-4 gap-2">
            {["MP4", "MOV", "WebM", "GIF"].map((f) => (
              <Badge key={f} variant="outline" className="justify-center py-2">{f}</Badge>
            ))}
          </div>
          <DialogFooter>
            <Button
              variant="gradient"
              onClick={() => {
                setExportOpen(false);
                toast.success("Export started — you'll get a notification when it's ready.");
              }}
            >
              <Download className="size-4" /> Start export
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
