"use client";

import { useEffect, useState } from "react";
import AppShell from "@/components/AppShell";
import { api } from "@/lib/api";
import type { BrandingPreset } from "@/lib/types";

const EMPTY_FORM = {
  name: "",
  font_family: "Inter",
  primary_color: "#7C3AED",
  accent_color: "#22D3EE",
  is_default: false,
};

export default function BrandingPage() {
  const [presets, setPresets] = useState<BrandingPreset[]>([]);
  const [form, setForm] = useState(EMPTY_FORM);
  const [assets, setAssets] = useState<Record<string, string>>({});
  const [saving, setSaving] = useState(false);

  async function load() {
    setPresets(await api.listBrandingPresets());
  }

  useEffect(() => {
    load();
  }, []);

  async function handleAssetUpload(kind: "logo" | "watermark" | "intro" | "outro", file: File) {
    const { path } = await api.uploadBrandingAsset(kind, file);
    setAssets((prev) => ({ ...prev, [kind]: path }));
  }

  async function createPreset() {
    setSaving(true);
    try {
      await api.createBrandingPreset({
        ...form,
        logo_path: assets.logo || "",
        watermark_path: assets.watermark || "",
        intro_path: assets.intro || "",
        outro_path: assets.outro || "",
      });
      setForm(EMPTY_FORM);
      setAssets({});
      await load();
    } finally {
      setSaving(false);
    }
  }

  async function removePreset(id: string) {
    await api.deleteBrandingPreset(id);
    await load();
  }

  return (
    <AppShell>
      <h1 className="mb-6 text-2xl font-semibold tracking-tight">Branding presets</h1>

      <section className="card mb-8 p-6">
        <h2 className="mb-4 text-lg font-semibold tracking-tight">New preset</h2>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <label className="text-sm text-gray-400">
            Name
            <input
              className="input mt-1"
              value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })}
            />
          </label>
          <label className="text-sm text-gray-400">
            Font
            <input
              className="input mt-1"
              value={form.font_family}
              onChange={(e) => setForm({ ...form, font_family: e.target.value })}
            />
          </label>
          <label className="text-sm text-gray-400">
            Primary color
            <input
              type="color"
              className="input mt-1 h-10"
              value={form.primary_color}
              onChange={(e) => setForm({ ...form, primary_color: e.target.value })}
            />
          </label>
          <label className="text-sm text-gray-400">
            Accent color
            <input
              type="color"
              className="input mt-1 h-10"
              value={form.accent_color}
              onChange={(e) => setForm({ ...form, accent_color: e.target.value })}
            />
          </label>
          <label className="text-sm text-gray-400">
            Logo
            <input
              type="file"
              accept="image/*"
              className="input mt-1"
              onChange={(e) => e.target.files?.[0] && handleAssetUpload("logo", e.target.files[0])}
            />
          </label>
          <label className="text-sm text-gray-400">
            Watermark
            <input
              type="file"
              accept="image/*"
              className="input mt-1"
              onChange={(e) => e.target.files?.[0] && handleAssetUpload("watermark", e.target.files[0])}
            />
          </label>
          <label className="text-sm text-gray-400">
            Intro clip
            <input
              type="file"
              accept="video/*"
              className="input mt-1"
              onChange={(e) => e.target.files?.[0] && handleAssetUpload("intro", e.target.files[0])}
            />
          </label>
          <label className="text-sm text-gray-400">
            Outro clip
            <input
              type="file"
              accept="video/*"
              className="input mt-1"
              onChange={(e) => e.target.files?.[0] && handleAssetUpload("outro", e.target.files[0])}
            />
          </label>
          <label className="flex items-center gap-2 text-sm text-gray-400">
            <input
              type="checkbox"
              checked={form.is_default}
              onChange={(e) => setForm({ ...form, is_default: e.target.checked })}
            />
            Set as default preset
          </label>
        </div>
        <button
          className="btn-primary mt-4"
          disabled={saving || !form.name}
          onClick={createPreset}
        >
          Save preset
        </button>
      </section>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {presets.map((preset) => (
          <div key={preset.id} className="card p-5">
            <div className="mb-3 flex items-center justify-between">
              <h3 className="font-medium">{preset.name}</h3>
              {preset.is_default && <span className="badge bg-brand-500/20 text-brand-400">Default</span>}
            </div>
            <div className="mb-3 flex gap-2">
              <span
                className="h-6 w-6 rounded-full border border-base-600"
                style={{ backgroundColor: preset.primary_color }}
              />
              <span
                className="h-6 w-6 rounded-full border border-base-600"
                style={{ backgroundColor: preset.accent_color }}
              />
            </div>
            <p className="text-xs text-gray-500">Font: {preset.font_family}</p>
            <button className="btn-danger mt-4 w-full" onClick={() => removePreset(preset.id)}>
              Delete
            </button>
          </div>
        ))}
        {presets.length === 0 && <p className="text-sm text-gray-500">No branding presets yet.</p>}
      </div>
    </AppShell>
  );
}
