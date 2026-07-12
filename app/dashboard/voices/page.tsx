"use client";

import * as React from "react";
import { toast } from "sonner";
import { Play, Volume2, Mic } from "lucide-react";
import { PageHeader } from "@/components/dashboard/page-header";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Slider } from "@/components/ui/slider";
import { Label } from "@/components/ui/label";
import { VOICES } from "@/lib/mock-data";
import { generateVoicePreview } from "@/lib/ai/engine";
import { cn, sleep } from "@/lib/utils";

const LANGUAGES = [
  "English", "Spanish", "German", "French", "Italian", "Swedish", "Portuguese", "Japanese", "Chinese", "Arabic", "Hindi",
];

export default function VoicesPage() {
  const [selected, setSelected] = React.useState(VOICES[0].id);
  const [playing, setPlaying] = React.useState<string | null>(null);
  const [pitch, setPitch] = React.useState([50]);
  const [speed, setSpeed] = React.useState([50]);
  const [energy, setEnergy] = React.useState([65]);
  const [pauses, setPauses] = React.useState([40]);
  const [emphasis, setEmphasis] = React.useState([55]);

  const voice = VOICES.find((v) => v.id === selected)!;

  async function preview(id: string) {
    setPlaying(id);
    await generateVoicePreview(id);
    toast.message("Playing voice preview…");
    await sleep(1300);
    setPlaying(null);
  }

  return (
    <div>
      <PageHeader title="Voices" description="Natural AI voices across 10 languages with full emotion control." />

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-[1fr_320px]">
        <div>
          <div className="mb-4 flex flex-wrap gap-1.5">
            {LANGUAGES.map((l) => (
              <Badge key={l} variant="outline">{l}</Badge>
            ))}
          </div>
          <div className="space-y-2.5">
            {VOICES.map((v) => (
              <Card
                key={v.id}
                onClick={() => setSelected(v.id)}
                className={cn(
                  "flex cursor-pointer items-center gap-3 p-4 transition-colors",
                  selected === v.id && "border-primary bg-primary/6 shadow-[0_0_0_1px_var(--primary)]"
                )}
              >
                <button
                  onClick={(e) => {
                    e.stopPropagation();
                    preview(v.id);
                  }}
                  className="flex size-10 shrink-0 items-center justify-center rounded-full bg-secondary"
                >
                  {playing === v.id ? (
                    <Volume2 className="size-4 animate-pulse text-primary" />
                  ) : (
                    <Play className="size-4" />
                  )}
                </button>
                <div className="min-w-0 flex-1">
                  <p className="font-medium">
                    {v.name} <span className="font-normal text-muted-foreground">· {v.gender} · {v.accent} {v.language}</span>
                  </p>
                  <p className="truncate text-sm text-muted-foreground">&ldquo;{v.sampleLine}&rdquo;</p>
                </div>
                <Badge variant="secondary">{v.emotion}</Badge>
              </Card>
            ))}
          </div>
        </div>

        <Card className="h-fit">
          <CardHeader>
            <CardTitle className="flex items-center gap-2"><Mic className="size-4" /> Voice controls</CardTitle>
            <CardDescription>Fine-tune {voice.name}&apos;s delivery.</CardDescription>
          </CardHeader>
          <CardContent className="space-y-5">
            {[
              { label: "Pitch", value: pitch, set: setPitch },
              { label: "Speed", value: speed, set: setSpeed },
              { label: "Energy", value: energy, set: setEnergy },
              { label: "Pauses", value: pauses, set: setPauses },
              { label: "Emphasis", value: emphasis, set: setEmphasis },
            ].map((c) => (
              <div key={c.label}>
                <div className="mb-2 flex items-center justify-between text-sm">
                  <Label>{c.label}</Label>
                  <span className="text-muted-foreground">{c.value[0]}</span>
                </div>
                <Slider value={c.value} onValueChange={c.set} max={100} step={1} />
              </div>
            ))}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
