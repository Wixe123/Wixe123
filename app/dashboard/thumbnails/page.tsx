"use client";

import * as React from "react";
import { toast } from "sonner";
import { Sparkles, RefreshCw, Download, Heart } from "lucide-react";
import { PageHeader } from "@/components/dashboard/page-header";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { generateThumbnails } from "@/lib/ai/engine";
import { cn } from "@/lib/utils";

type Thumb = Awaited<ReturnType<typeof generateThumbnails>>[number];

export default function ThumbnailsPage() {
  const [product, setProduct] = React.useState("GlowSerum Vitamin C Serum");
  const [loading, setLoading] = React.useState(false);
  const [thumbs, setThumbs] = React.useState<Thumb[]>([]);
  const [favorites, setFavorites] = React.useState<Set<string>>(new Set());
  const [downloadingId, setDownloadingId] = React.useState<string | null>(null);

  async function handleGenerate() {
    setLoading(true);
    const result = await generateThumbnails(product, 10);
    setThumbs(result);
    setLoading(false);
  }

  function toggleFavorite(id: string) {
    setFavorites((prev) => {
      const next = new Set(prev);
      if (next.has(id)) {
        next.delete(id);
      } else {
        next.add(id);
      }
      return next;
    });
  }

  async function downloadThumbnail(t: Thumb) {
    setDownloadingId(t.id);
    try {
      const res = await fetch("/api/render-thumbnail", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ style: t.style, gradient: t.gradient, ctrEstimate: t.ctrEstimate }),
      });
      if (!res.ok) throw new Error("Render failed");
      const blob = await res.blob();
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = `thumbnail-${t.style.toLowerCase()}.png`;
      document.body.appendChild(a);
      a.click();
      a.remove();
      URL.revokeObjectURL(url);
      toast.success("Real PNG downloaded");
    } catch {
      toast.error("Could not render thumbnail");
    } finally {
      setDownloadingId(null);
    }
  }

  return (
    <div>
      <PageHeader title="Thumbnails" description="Generate 10 scroll-stopping thumbnails in different styles." />

      <div className="mb-6 flex flex-col gap-3 sm:flex-row">
        <Input value={product} onChange={(e) => setProduct(e.target.value)} placeholder="Product name" className="sm:max-w-sm" />
        <Button variant="gradient" onClick={handleGenerate} disabled={loading}>
          {loading ? <RefreshCw className="size-4 animate-spin" /> : <Sparkles className="size-4" />}
          {loading ? "Generating…" : "Generate 10 thumbnails"}
        </Button>
      </div>

      {thumbs.length === 0 ? (
        <Card className="flex flex-col items-center gap-2 p-16 text-center text-muted-foreground">
          <Sparkles className="size-6 text-primary" />
          Your thumbnails will appear here, ranked by predicted CTR.
        </Card>
      ) : (
        <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-5">
          {thumbs.map((t) => (
            <Card key={t.id} className="overflow-hidden p-0">
              <div
                className={cn(
                  "relative flex aspect-9/16 items-center justify-center bg-gradient-to-br text-4xl text-white",
                  t.gradient
                )}
              >
                <span>🖼️</span>
                <button
                  onClick={() => toggleFavorite(t.id)}
                  className="absolute top-2 right-2 flex size-7 items-center justify-center rounded-full bg-black/30 backdrop-blur"
                >
                  <Heart className={cn("size-3.5", favorites.has(t.id) ? "fill-rose-500 text-rose-500" : "text-white")} />
                </button>
                <Badge className="absolute top-2 left-2 bg-black/30 text-white" variant="secondary">
                  {t.style}
                </Badge>
              </div>
              <div className="flex items-center justify-between p-2.5">
                <span className="text-xs font-medium text-emerald-500">{t.ctrEstimate}% est. CTR</span>
                <Button
                  variant="ghost"
                  size="icon-sm"
                  onClick={() => downloadThumbnail(t)}
                  disabled={downloadingId === t.id}
                >
                  {downloadingId === t.id ? (
                    <RefreshCw className="size-3.5 animate-spin" />
                  ) : (
                    <Download className="size-3.5" />
                  )}
                </Button>
              </div>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
