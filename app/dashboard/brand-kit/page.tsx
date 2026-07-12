"use client";

import * as React from "react";
import { toast } from "sonner";
import { Upload, Plus, X } from "lucide-react";
import { PageHeader } from "@/components/dashboard/page-header";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import { Select, SelectTrigger, SelectValue, SelectContent, SelectItem } from "@/components/ui/select";
import { Badge } from "@/components/ui/badge";

const DEFAULT_COLORS = ["#7C3AED", "#EC4899", "#6366F1", "#10B981", "#F59E0B"];
const FONTS = ["Plus Jakarta Sans", "Inter", "Poppins", "Sora", "Manrope", "DM Sans"];

export default function BrandKitPage() {
  const [colors, setColors] = React.useState(DEFAULT_COLORS);
  const [products, setProducts] = React.useState(["GlowSerum Vitamin C Serum", "Overnight Recovery Mask"]);
  const [newProduct, setNewProduct] = React.useState("");

  function updateColor(i: number, value: string) {
    setColors((c) => c.map((col, idx) => (idx === i ? value : col)));
  }

  function addProduct() {
    if (!newProduct.trim()) return;
    setProducts((p) => [...p, newProduct.trim()]);
    setNewProduct("");
  }

  return (
    <div>
      <PageHeader
        title="Brand Kit"
        description="Upload your logo, fonts, and colors once — every export inherits them automatically."
        actions={<Button variant="gradient" onClick={() => toast.success("Brand kit saved")}>Save changes</Button>}
      />

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>Logo</CardTitle>
            <CardDescription>Used on thumbnails and end cards.</CardDescription>
          </CardHeader>
          <CardContent>
            <label className="flex cursor-pointer flex-col items-center justify-center gap-2 rounded-xl border border-dashed border-border p-10 text-center text-sm text-muted-foreground hover:bg-secondary/50">
              <Upload className="size-6" />
              Click to upload logo (SVG or PNG)
              <input type="file" className="hidden" onChange={() => toast.success("Logo uploaded")} />
            </label>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Brand colors</CardTitle>
            <CardDescription>Applied to captions, overlays, and thumbnails.</CardDescription>
          </CardHeader>
          <CardContent className="flex flex-wrap gap-3">
            {colors.map((c, i) => (
              <div key={i} className="flex flex-col items-center gap-1.5">
                <input
                  type="color"
                  value={c}
                  onChange={(e) => updateColor(i, e.target.value)}
                  className="size-12 cursor-pointer rounded-xl border border-border bg-transparent p-0"
                />
                <span className="text-[10px] text-muted-foreground uppercase">{c}</span>
              </div>
            ))}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Fonts</CardTitle>
            <CardDescription>Heading and body typefaces for on-screen text.</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-1.5">
              <Label>Heading font</Label>
              <Select defaultValue={FONTS[0]}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>{FONTS.map((f) => <SelectItem key={f} value={f}>{f}</SelectItem>)}</SelectContent>
              </Select>
            </div>
            <div className="space-y-1.5">
              <Label>Body font</Label>
              <Select defaultValue={FONTS[1]}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>{FONTS.map((f) => <SelectItem key={f} value={f}>{f}</SelectItem>)}</SelectContent>
              </Select>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Brand voice</CardTitle>
            <CardDescription>Guides tone across scripts and copy.</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <Textarea
              defaultValue="Warm, honest, a little playful. We sound like a friend giving real advice — never salesy, never robotic."
              rows={4}
            />
            <div className="space-y-1.5">
              <Label>Website</Label>
              <Input defaultValue="https://loopskincare.com" />
            </div>
          </CardContent>
        </Card>

        <Card className="lg:col-span-2">
          <CardHeader>
            <CardTitle>Products</CardTitle>
            <CardDescription>Auto-suggested when starting a new project.</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="flex flex-wrap gap-2">
              {products.map((p) => (
                <Badge key={p} variant="secondary" className="gap-1.5 py-1.5 pr-1.5">
                  {p}
                  <button onClick={() => setProducts((list) => list.filter((x) => x !== p))}>
                    <X className="size-3" />
                  </button>
                </Badge>
              ))}
            </div>
            <div className="mt-4 flex gap-2">
              <Input
                value={newProduct}
                onChange={(e) => setNewProduct(e.target.value)}
                placeholder="Add a product…"
                onKeyDown={(e) => e.key === "Enter" && addProduct()}
              />
              <Button variant="outline" onClick={addProduct}><Plus className="size-4" /> Add</Button>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
