"use client";

import * as React from "react";
import { toast } from "sonner";
import {
  Play, Scissors, ZoomIn, Wand2, Captions, Music4, Layers, Download, Sparkles,
} from "lucide-react";
import { PageHeader } from "@/components/dashboard/page-header";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Switch } from "@/components/ui/switch";
import { Label } from "@/components/ui/label";
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs";
import { Badge } from "@/components/ui/badge";
import {
  Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter,
} from "@/components/ui/dialog";

const AI_EDITS = [
  { key: "silence", label: "Cut silence", icon: Scissors, defaultOn: true },
  { key: "filler", label: "Remove filler words", icon: Wand2, defaultOn: true },
  { key: "jumpcuts", label: "Add jump cuts", icon: Layers, defaultOn: false },
  { key: "zoom", label: "Add zoom-ins", icon: ZoomIn, defaultOn: true },
  { key: "captions", label: "Auto captions", icon: Captions, defaultOn: true },
  { key: "highlight", label: "Highlight keywords", icon: Sparkles, defaultOn: true },
  { key: "crop", label: "Auto crop", icon: Layers, defaultOn: false },
  { key: "grade", label: "Auto color grading", icon: Wand2, defaultOn: false },
  { key: "audio", label: "Auto audio enhancement", icon: Music4, defaultOn: true },
];

const RATIOS = ["9:16", "1:1", "16:9"];

export default function StudioPage() {
  const [ratio, setRatio] = React.useState("9:16");
  const [edits, setEdits] = React.useState(
    Object.fromEntries(AI_EDITS.map((e) => [e.key, e.defaultOn]))
  );
  const [exportOpen, setExportOpen] = React.useState(false);

  return (
    <div>
      <PageHeader
        title="Video Studio"
        description="Fine-tune captions, effects, and AI editing before export."
        actions={
          <Button variant="gradient" onClick={() => setExportOpen(true)}>
            <Download className="size-4" /> Export
          </Button>
        }
      />

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-[320px_1fr_320px]">
        <Card className="order-2 lg:order-1">
          <CardHeader>
            <CardTitle>AI editing</CardTitle>
            <CardDescription>Applied automatically before render.</CardDescription>
          </CardHeader>
          <CardContent className="space-y-3">
            {AI_EDITS.map((e) => (
              <div key={e.key} className="flex items-center justify-between">
                <Label htmlFor={e.key} className="flex items-center gap-2.5 font-normal">
                  <e.icon className="size-4 text-muted-foreground" /> {e.label}
                </Label>
                <Switch
                  id={e.key}
                  checked={edits[e.key]}
                  onCheckedChange={(v) => setEdits((s) => ({ ...s, [e.key]: v }))}
                />
              </div>
            ))}
          </CardContent>
        </Card>

        <div className="order-1 flex flex-col items-center lg:order-2">
          <div className="mb-4 flex gap-2">
            {RATIOS.map((r) => (
              <button
                key={r}
                onClick={() => setRatio(r)}
                className={`rounded-lg border px-3 py-1.5 text-sm font-medium ${
                  ratio === r ? "border-primary bg-primary/10 text-primary" : "border-border text-muted-foreground"
                }`}
              >
                {r}
              </button>
            ))}
          </div>
          <div
            className={`relative flex items-center justify-center overflow-hidden rounded-2xl bg-gradient-to-br from-violet-500 to-fuchsia-500 text-white shadow-2xl ${
              ratio === "9:16" ? "aspect-9/16 w-64" : ratio === "1:1" ? "aspect-square w-80" : "aspect-video w-full max-w-2xl"
            }`}
          >
            <span className="text-6xl">✨</span>
            <button className="absolute inset-0 flex items-center justify-center bg-black/0 opacity-0 transition-opacity hover:bg-black/20 hover:opacity-100">
              <span className="flex size-14 items-center justify-center rounded-full bg-white/90 text-black">
                <Play className="size-6" />
              </span>
            </button>
            {edits.captions && (
              <div className="absolute inset-x-0 bottom-8 px-6 text-center">
                <span className="rounded-md bg-black/60 px-2 py-1 text-sm font-bold backdrop-blur">
                  I bought this so you don&apos;t have to
                </span>
              </div>
            )}
          </div>
          <p className="mt-3 text-xs text-muted-foreground">GlowSerum — Morning Routine Hook · 0:28</p>
        </div>

        <Card className="order-3">
          <CardHeader>
            <CardTitle>Enhancements</CardTitle>
            <CardDescription>B-roll, music, and overlays.</CardDescription>
          </CardHeader>
          <CardContent>
            <Tabs defaultValue="captions">
              <TabsList className="w-full">
                <TabsTrigger value="captions">Captions</TabsTrigger>
                <TabsTrigger value="music">Music</TabsTrigger>
                <TabsTrigger value="broll">B-roll</TabsTrigger>
              </TabsList>
              <TabsContent value="captions" className="space-y-2">
                {["Bold", "Emoji", "Minimal", "Karaoke"].map((s) => (
                  <div key={s} className="flex items-center justify-between rounded-xl border border-border p-3 text-sm">
                    {s} captions
                    <Badge variant="outline">Style</Badge>
                  </div>
                ))}
              </TabsContent>
              <TabsContent value="music" className="space-y-2">
                {["Upbeat Pop", "Chill Lo-fi", "Cinematic", "Trending TikTok"].map((s) => (
                  <button
                    key={s}
                    onClick={() => toast.message(`Playing "${s}"…`)}
                    className="flex w-full items-center justify-between rounded-xl border border-border p-3 text-left text-sm hover:bg-secondary/60"
                  >
                    {s} <Play className="size-3.5" />
                  </button>
                ))}
              </TabsContent>
              <TabsContent value="broll" className="space-y-2">
                {["Product close-up", "Lifestyle B-roll", "Unboxing", "Before / after"].map((s) => (
                  <div key={s} className="flex items-center justify-between rounded-xl border border-border p-3 text-sm">
                    {s}
                    <Badge variant="secondary">Stock</Badge>
                  </div>
                ))}
              </TabsContent>
            </Tabs>
          </CardContent>
        </Card>
      </div>

      <Dialog open={exportOpen} onOpenChange={setExportOpen}>
        <DialogContent>
          <DialogHeader><DialogTitle>Export video</DialogTitle></DialogHeader>
          <div className="grid grid-cols-3 gap-2">
            {["1080p", "2K", "4K"].map((r) => (
              <Badge key={r} variant="outline" className="justify-center py-2">{r}</Badge>
            ))}
          </div>
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
                toast.success("Export queued — rendering in the background.");
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
