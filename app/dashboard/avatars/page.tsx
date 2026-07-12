"use client";

import * as React from "react";
import { toast } from "sonner";
import { PageHeader } from "@/components/dashboard/page-header";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Select, SelectTrigger, SelectValue, SelectContent, SelectItem } from "@/components/ui/select";
import { AVATARS } from "@/lib/mock-data";
import { cn } from "@/lib/utils";

const CATEGORIES = ["All", ...Array.from(new Set(AVATARS.map((a) => a.category)))];
const GENDERS = ["All", "Female", "Male"];
const ROOMS = ["All", ...Array.from(new Set(AVATARS.map((a) => a.room)))];

const TRAITS = [
  "Natural blinking", "Breathing", "Eye movement", "Natural smiles",
  "Head movement", "Body gestures", "Lip sync", "Emotion control",
];

export default function AvatarsPage() {
  const [category, setCategory] = React.useState("All");
  const [gender, setGender] = React.useState("All");
  const [room, setRoom] = React.useState("All");

  const filtered = AVATARS.filter(
    (a) =>
      (category === "All" || a.category === category) &&
      (gender === "All" || a.gender === gender) &&
      (room === "All" || a.room === room)
  );

  return (
    <div>
      <PageHeader
        title="Avatars"
        description={`${AVATARS.length} AI avatars — natural blinking, breathing, and gestures built in.`}
      />

      <div className="mb-6 flex flex-wrap gap-3">
        <Select value={category} onValueChange={setCategory}>
          <SelectTrigger className="w-40"><SelectValue /></SelectTrigger>
          <SelectContent>{CATEGORIES.map((c) => <SelectItem key={c} value={c}>{c}</SelectItem>)}</SelectContent>
        </Select>
        <Select value={gender} onValueChange={setGender}>
          <SelectTrigger className="w-32"><SelectValue /></SelectTrigger>
          <SelectContent>{GENDERS.map((g) => <SelectItem key={g} value={g}>{g}</SelectItem>)}</SelectContent>
        </Select>
        <Select value={room} onValueChange={setRoom}>
          <SelectTrigger className="w-40"><SelectValue /></SelectTrigger>
          <SelectContent>{ROOMS.map((r) => <SelectItem key={r} value={r}>{r}</SelectItem>)}</SelectContent>
        </Select>
        <span className="ml-auto self-center text-sm text-muted-foreground">{filtered.length} avatars</span>
      </div>

      <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-6">
        {filtered.map((a) => (
          <Card
            key={a.id}
            onClick={() => toast.success(`${a.name} selected — head to New Project to cast them.`)}
            className="group cursor-pointer overflow-hidden p-0 transition-transform hover:-translate-y-0.5 hover:shadow-lg"
          >
            <div
              className={cn(
                "relative flex aspect-square items-center justify-center bg-gradient-to-br text-5xl text-white",
                a.gradient
              )}
            >
              {a.emoji}
              <Badge variant="secondary" className="absolute top-2 left-2 bg-black/30 text-white backdrop-blur">
                {a.room}
              </Badge>
            </div>
            <div className="p-3">
              <p className="text-sm font-semibold">{a.name}</p>
              <p className="text-xs text-muted-foreground">
                {a.age} · {a.ethnicity}
              </p>
              <div className="mt-2 flex flex-wrap gap-1">
                <Badge variant="outline" className="text-[10px]">{a.category}</Badge>
                <Badge variant="outline" className="text-[10px]">{a.accent}</Badge>
              </div>
            </div>
          </Card>
        ))}
      </div>

      <Card className="mt-8 p-6">
        <p className="mb-3 text-sm font-semibold">Every avatar includes</p>
        <div className="flex flex-wrap gap-2">
          {TRAITS.map((t) => (
            <Badge key={t} variant="secondary">{t}</Badge>
          ))}
        </div>
      </Card>
    </div>
  );
}
