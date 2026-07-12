"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Heart, Download, MoreHorizontal, Trash2 } from "lucide-react";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import type { RealProject } from "@/lib/types";
import { cn, timeAgo } from "@/lib/utils";

const STATUS_VARIANT: Record<string, "success" | "warning" | "secondary" | "destructive"> = {
  Ready: "success",
  Rendering: "warning",
  Draft: "secondary",
  Failed: "destructive",
};

export function ProjectCard({
  project,
  onChange,
}: {
  project: RealProject;
  onChange?: () => void;
}) {
  const router = useRouter();
  const [busy, setBusy] = React.useState(false);

  async function toggleFavorite() {
    setBusy(true);
    try {
      await fetch("/api/projects/favorite", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ id: project.id }),
      });
      router.refresh();
      onChange?.();
    } finally {
      setBusy(false);
    }
  }

  async function deleteProject() {
    setBusy(true);
    try {
      await fetch("/api/projects/delete", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ id: project.id }),
      });
      toast.success("Project deleted");
      router.refresh();
      onChange?.();
    } finally {
      setBusy(false);
    }
  }

  function download() {
    window.location.href = `/api/download?id=${project.id}&type=video`;
  }

  return (
    <Card className="group overflow-hidden p-0 transition-shadow hover:shadow-lg">
      <div
        className={cn(
          "relative flex aspect-video items-center justify-center bg-gradient-to-br text-5xl text-white",
          project.avatarGradient
        )}
      >
        {project.hasVideo ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={`/api/download?id=${project.id}&type=thumbnail`}
            alt=""
            className="absolute inset-0 size-full object-cover"
          />
        ) : (
          project.avatarEmoji
        )}
        <span className="absolute top-2 left-2">
          <Badge variant={STATUS_VARIANT[project.status] ?? "secondary"}>{project.status}</Badge>
        </span>
        <button
          onClick={toggleFavorite}
          disabled={busy}
          className="absolute top-2.5 right-2.5 flex size-6 items-center justify-center rounded-full bg-black/30 backdrop-blur"
        >
          <Heart className={cn("size-3.5", project.favorite ? "fill-rose-500 text-rose-500" : "text-white")} />
        </button>
      </div>
      <div className="p-4">
        <p className="truncate text-sm font-semibold">{project.name}</p>
        <p className="mt-0.5 text-xs text-muted-foreground">
          {project.platform} · {project.audience} · {timeAgo(project.createdAt)}
        </p>
        <div className="mt-3 flex items-center justify-between">
          {project.viralityScore > 0 ? (
            <span
              className={cn(
                "text-xs font-semibold",
                project.viralityScore >= 85
                  ? "text-emerald-500"
                  : project.viralityScore >= 70
                    ? "text-amber-500"
                    : "text-muted-foreground"
              )}
            >
              {project.viralityScore} viral score
            </span>
          ) : (
            <span className="text-xs text-muted-foreground">—</span>
          )}
          <div className="flex items-center gap-1">
            <Button variant="ghost" size="icon-sm" onClick={download} disabled={!project.hasVideo}>
              <Download className="size-3.5" />
            </Button>
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button variant="ghost" size="icon-sm">
                  <MoreHorizontal className="size-3.5" />
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end">
                <DropdownMenuItem onSelect={toggleFavorite}>
                  <Heart className="size-4" /> {project.favorite ? "Remove favorite" : "Add to favorites"}
                </DropdownMenuItem>
                <DropdownMenuItem onSelect={deleteProject} className="text-destructive focus:text-destructive">
                  <Trash2 className="size-4" /> Delete
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
          </div>
        </div>
      </div>
    </Card>
  );
}
