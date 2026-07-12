import { Heart, Download, MoreHorizontal, Clock } from "lucide-react";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import type { Project } from "@/lib/mock-data";
import { cn } from "@/lib/utils";

const STATUS_VARIANT: Record<Project["status"], "success" | "warning" | "secondary" | "destructive"> = {
  Ready: "success",
  Rendering: "warning",
  Draft: "secondary",
  Failed: "destructive",
};

export function ProjectCard({ project }: { project: Project }) {
  return (
    <Card className="group overflow-hidden p-0 transition-shadow hover:shadow-lg">
      <div className="relative flex aspect-video items-center justify-center bg-gradient-to-br from-secondary to-secondary/50 text-5xl">
        {project.thumbnail}
        <span className="absolute top-2 left-2">
          <Badge variant={STATUS_VARIANT[project.status]}>{project.status}</Badge>
        </span>
        {project.favorite && (
          <Heart className="absolute top-2.5 right-2.5 size-4 fill-rose-500 text-rose-500" />
        )}
        {project.duration !== "—" && (
          <span className="absolute bottom-2 right-2 flex items-center gap-1 rounded-md bg-black/50 px-1.5 py-0.5 text-[10px] font-medium text-white backdrop-blur">
            <Clock className="size-2.5" /> {project.duration}
          </span>
        )}
      </div>
      <div className="p-4">
        <p className="truncate text-sm font-semibold">{project.name}</p>
        <p className="mt-0.5 text-xs text-muted-foreground">
          {project.platform} · {project.audience} · {project.createdAt}
        </p>
        <div className="mt-3 flex items-center justify-between">
          {project.viralScore > 0 ? (
            <span
              className={cn(
                "text-xs font-semibold",
                project.viralScore >= 85 ? "text-emerald-500" : project.viralScore >= 70 ? "text-amber-500" : "text-muted-foreground"
              )}
            >
              {project.viralScore} viral score
            </span>
          ) : (
            <span className="text-xs text-muted-foreground">—</span>
          )}
          <div className="flex items-center gap-1">
            <Button variant="ghost" size="icon-sm">
              <Download className="size-3.5" />
            </Button>
            <Button variant="ghost" size="icon-sm">
              <MoreHorizontal className="size-3.5" />
            </Button>
          </div>
        </div>
      </div>
    </Card>
  );
}
