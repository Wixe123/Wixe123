"use client";

import * as React from "react";
import { toast } from "sonner";
import { CreditCard, Download, Check } from "lucide-react";
import { PageHeader } from "@/components/dashboard/page-header";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Progress } from "@/components/ui/progress";
import { PRICING_PLANS, DASHBOARD_STATS } from "@/lib/mock-data";
import { cn, formatCurrency } from "@/lib/utils";

const INVOICES = [
  { id: "INV-1042", date: "Jul 1, 2026", amount: 99, status: "Paid" },
  { id: "INV-1031", date: "Jun 1, 2026", amount: 99, status: "Paid" },
  { id: "INV-1020", date: "May 1, 2026", amount: 99, status: "Paid" },
  { id: "INV-1008", date: "Apr 1, 2026", amount: 39, status: "Paid" },
];

export default function BillingPage() {
  const currentPlanId = "pro";
  const pct = Math.round((DASHBOARD_STATS.creditsRemaining / DASHBOARD_STATS.creditsTotal) * 100);

  return (
    <div>
      <PageHeader title="Billing" description="Manage your plan, usage, and payment method." />

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <Card className="p-5 sm:col-span-2">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-muted-foreground">Current plan</p>
              <p className="font-display text-2xl font-bold">Pro — $99/mo</p>
            </div>
            <Button variant="outline">Change plan</Button>
          </div>
          <div className="mt-4">
            <div className="mb-1.5 flex items-center justify-between text-sm">
              <span className="text-muted-foreground">Credits used this cycle</span>
              <span className="font-medium">{DASHBOARD_STATS.creditsTotal - DASHBOARD_STATS.creditsRemaining}/{DASHBOARD_STATS.creditsTotal}</span>
            </div>
            <Progress value={100 - pct} />
            <p className="mt-2 text-xs text-muted-foreground">Renews on August 1, 2026 · Credits roll over for 60 days</p>
          </div>
        </Card>

        <Card className="flex items-center gap-3 p-5">
          <span className="flex size-10 items-center justify-center rounded-xl bg-secondary">
            <CreditCard className="size-5" />
          </span>
          <div className="flex-1">
            <p className="text-sm font-medium">Visa •••• 4242</p>
            <p className="text-xs text-muted-foreground">Expires 08/28</p>
          </div>
          <Button variant="ghost" size="sm">Edit</Button>
        </Card>
      </div>

      <div className="mt-8 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {PRICING_PLANS.map((plan) => (
          <Card key={plan.id} className={cn("p-5", plan.id === currentPlanId && "border-primary shadow-[0_0_0_1px_var(--primary)]")}>
            {plan.id === currentPlanId && <Badge variant="gradient" className="mb-2 w-fit">Current plan</Badge>}
            <p className="font-display text-lg font-semibold">{plan.name}</p>
            <p className="mt-1 font-display text-2xl font-bold">
              {plan.price === 0 ? "Custom" : `$${plan.price}`}
              {plan.price > 0 && <span className="text-sm text-muted-foreground">/mo</span>}
            </p>
            <ul className="mt-3 space-y-1.5">
              {plan.features.slice(0, 3).map((f) => (
                <li key={f} className="flex items-start gap-1.5 text-xs text-muted-foreground">
                  <Check className="mt-0.5 size-3 shrink-0 text-primary" /> {f}
                </li>
              ))}
            </ul>
            <Button
              variant={plan.id === currentPlanId ? "outline" : "gradient"}
              className="mt-4 w-full"
              disabled={plan.id === currentPlanId}
              onClick={() => toast.success(`Switched to ${plan.name}`)}
            >
              {plan.id === currentPlanId ? "Current plan" : plan.cta}
            </Button>
          </Card>
        ))}
      </div>

      <Card className="mt-8">
        <CardHeader>
          <CardTitle>Invoice history</CardTitle>
          <CardDescription>Download past invoices for your records.</CardDescription>
        </CardHeader>
        <CardContent className="p-0">
          <div className="divide-y divide-border">
            {INVOICES.map((inv) => (
              <div key={inv.id} className="flex items-center justify-between px-6 py-3.5 text-sm">
                <span className="font-medium">{inv.id}</span>
                <span className="text-muted-foreground">{inv.date}</span>
                <span>{formatCurrency(inv.amount)}</span>
                <Badge variant="success">{inv.status}</Badge>
                <Button variant="ghost" size="icon-sm" onClick={() => toast.success(`Downloading ${inv.id}`)}>
                  <Download className="size-3.5" />
                </Button>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>

      <Card className="mt-8 p-6">
        <p className="font-medium">Referral & affiliate program</p>
        <p className="mt-1 text-sm text-muted-foreground">
          Earn 20% recurring commission for every brand you refer to CreatorAI.
        </p>
        <Button variant="outline" className="mt-3" onClick={() => toast.success("Referral link copied")}>
          Copy referral link
        </Button>
      </Card>
    </div>
  );
}
