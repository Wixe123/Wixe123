"use client";

import * as React from "react";
import Link from "next/link";
import { Plus, Search, SlidersHorizontal, RefreshCw, Sparkles } from "lucide-react";
import { PageHeader } from "@/components/dashboard/page-header";
import { ProjectCard } from "@/components/dashboard/project-card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import type { RealProject } from "@/lib/types";

const FILTERS = ["All", "Ready", "Rendering", "Draft", "Failed", "Favorites"] as const;

export default function ProjectsPage() {
  const [filter, setFilter] = React.useState<(typeof FILTERS)[number]>("All");
  const [query, setQuery] = React.useState("");
  const [projects, setProjects] = React.useState<RealProject[]>([]);
  const [loading, setLoading] = React.useState(true);

  const refetch = React.useCallback(() => {
    return fetch("/api/projects")
      .then((res) => res.json())
      .then((data) => setProjects(data.projects ?? []));
  }, []);

  React.useEffect(() => {
    refetch().finally(() => setLoading(false));
  }, [refetch]);

  const filtered = projects.filter((p) => {
    const matchesFilter =
      filter === "All" ? true : filter === "Favorites" ? p.favorite : p.status === filter;
    const matchesQuery = p.name.toLowerCase().includes(query.toLowerCase());
    return matchesFilter && matchesQuery;
  });

  return (
    <div>
      <PageHeader
        title="Projects"
        description={`${projects.length} ad${projects.length === 1 ? "" : "s"} generated across all platforms.`}
        actions={
          <Button asChild variant="gradient">
            <Link href="/dashboard/projects/new">
              <Plus className="size-4" /> New project
            </Link>
          </Button>
        }
      />

      <div className="mb-6 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <Tabs value={filter} onValueChange={(v) => setFilter(v as typeof filter)}>
          <TabsList>
            {FILTERS.map((f) => (
              <TabsTrigger key={f} value={f}>
                {f}
              </TabsTrigger>
            ))}
          </TabsList>
        </Tabs>
        <div className="flex gap-2">
          <div className="relative">
            <Search className="absolute top-1/2 left-3 size-4 -translate-y-1/2 text-muted-foreground" />
            <Input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Search projects…"
              className="w-56 pl-9"
            />
          </div>
          <Button variant="outline" size="icon">
            <SlidersHorizontal className="size-4" />
          </Button>
        </div>
      </div>

      {loading ? (
        <div className="flex flex-col items-center gap-2 rounded-2xl border border-dashed border-border p-16 text-center text-muted-foreground">
          <RefreshCw className="size-5 animate-spin text-primary" />
          Loading your projects…
        </div>
      ) : projects.length === 0 ? (
        <div className="flex flex-col items-center gap-3 rounded-2xl border border-dashed border-border p-16 text-center text-muted-foreground">
          <Sparkles className="size-6 text-primary" />
          You haven&apos;t created any ads yet.
          <Button asChild variant="gradient" size="sm">
            <Link href="/dashboard/projects/new">Create your first ad</Link>
          </Button>
        </div>
      ) : filtered.length === 0 ? (
        <div className="rounded-2xl border border-dashed border-border p-16 text-center text-muted-foreground">
          No projects match your filters.
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
          {filtered.map((p) => (
            <ProjectCard key={p.id} project={p} onChange={refetch} />
          ))}
        </div>
      )}
    </div>
  );
}
