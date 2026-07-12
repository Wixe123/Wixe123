import Link from "next/link";
import {
  Clapperboard, Zap, Download, Heart, DollarSign, Eye, Gauge, TrendingUp, ArrowRight, Sparkles,
} from "lucide-react";
import { PageHeader } from "@/components/dashboard/page-header";
import { StatCard } from "@/components/dashboard/stat-card";
import { PerformanceChart } from "@/components/dashboard/performance-chart";
import { ProjectCard } from "@/components/dashboard/project-card";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Progress } from "@/components/ui/progress";
import { DASHBOARD_STATS, TOP_HOOKS, SCORE_BREAKDOWN } from "@/lib/mock-data";
import { formatCurrency } from "@/lib/utils";
import { getCurrentUser } from "@/lib/server/auth";
import { listProjects, toClientProject } from "@/lib/server/projects";

export default async function DashboardPage() {
  const user = await getCurrentUser();
  const projects = user ? listProjects(user.id).map(toClientProject) : [];
  const favoritesCount = projects.filter((p) => p.favorite).length;
  const avgOptimization = projects.length
    ? Math.round(projects.reduce((sum, p) => sum + p.adQualityScore, 0) / projects.length)
    : DASHBOARD_STATS.avgOptimizationScore;

  return (
    <div>
      <PageHeader
        title={`Welcome back${user ? `, ${user.name.split(" ")[0]}` : ""}`}
        description="Here's how your UGC ads are performing this week."
        actions={
          <Button asChild variant="gradient">
            <Link href="/dashboard/projects/new">
              <Clapperboard className="size-4" /> New ad
            </Link>
          </Button>
        }
      />

      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <StatCard label="Videos created" value={projects.length.toString()} icon={Clapperboard} />
        <StatCard
          label="Credits remaining"
          value={`${DASHBOARD_STATS.creditsRemaining}/${DASHBOARD_STATS.creditsTotal}`}
          icon={Zap}
        />
        <StatCard label="Downloads" value={DASHBOARD_STATS.downloads.toString()} icon={Download} trend={8} />
        <StatCard label="Favorites" value={favoritesCount.toString()} icon={Heart} />
        <StatCard
          label="Est. revenue generated"
          value={formatCurrency(DASHBOARD_STATS.estimatedRevenue)}
          icon={DollarSign}
          trend={21}
        />
        <StatCard label="Avg. watch time" value={`${DASHBOARD_STATS.avgWatchTime}s`} icon={Eye} trend={5} />
        <StatCard
          label="AI optimization score"
          value={`${avgOptimization}/100`}
          icon={Gauge}
        />
        <StatCard label="Generation history" value={`${projects.length} runs`} icon={TrendingUp} />
      </div>

      <div className="mt-6 grid grid-cols-1 gap-4 lg:grid-cols-3">
        <Card className="lg:col-span-2">
          <CardHeader>
            <CardTitle>Weekly performance</CardTitle>
            <CardDescription>Illustrative — connect ad platform analytics to make this real.</CardDescription>
          </CardHeader>
          <CardContent>
            <PerformanceChart />
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Optimization score breakdown</CardTitle>
            <CardDescription>Average across all active projects.</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            {SCORE_BREAKDOWN.map((s) => (
              <div key={s.label}>
                <div className="mb-1.5 flex items-center justify-between text-sm">
                  <span className="text-muted-foreground">{s.label}</span>
                  <span className="font-medium">{s.value}</span>
                </div>
                <Progress value={s.value} />
              </div>
            ))}
          </CardContent>
        </Card>
      </div>

      <div className="mt-6 grid grid-cols-1 gap-4 lg:grid-cols-3">
        <Card className="lg:col-span-2">
          <CardHeader className="flex-row items-center justify-between space-y-0">
            <div>
              <CardTitle>Recent projects</CardTitle>
              <CardDescription>Your latest generated ads — real, saved to your account.</CardDescription>
            </div>
            <Button variant="ghost" size="sm" asChild>
              <Link href="/dashboard/projects">
                View all <ArrowRight className="size-3.5" />
              </Link>
            </Button>
          </CardHeader>
          <CardContent className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            {projects.length === 0 ? (
              <div className="col-span-full flex flex-col items-center gap-3 rounded-xl border border-dashed border-border py-12 text-center text-sm text-muted-foreground">
                <Sparkles className="size-5 text-primary" />
                No ads yet — create your first one.
                <Button asChild variant="gradient" size="sm">
                  <Link href="/dashboard/projects/new">New ad</Link>
                </Button>
              </div>
            ) : (
              projects.slice(0, 4).map((p) => <ProjectCard key={p.id} project={p} />)
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Top performing hooks</CardTitle>
            <CardDescription>Illustrative industry benchmarks.</CardDescription>
          </CardHeader>
          <CardContent className="space-y-3">
            {TOP_HOOKS.map((h, i) => (
              <div key={h.hook} className="flex items-start gap-3 rounded-xl border border-border p-3">
                <span className="flex size-6 shrink-0 items-center justify-center rounded-full bg-primary/12 text-xs font-semibold text-primary">
                  {i + 1}
                </span>
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-medium">{h.hook}</p>
                  <p className="mt-0.5 text-xs text-muted-foreground">
                    {h.score} score · {h.uses} uses
                  </p>
                </div>
              </div>
            ))}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
