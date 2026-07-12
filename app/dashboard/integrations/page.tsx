"use client";

import * as React from "react";
import { toast } from "sonner";
import { PageHeader } from "@/components/dashboard/page-header";
import { Card } from "@/components/ui/card";
import { Switch } from "@/components/ui/switch";
import { Badge } from "@/components/ui/badge";
import { INTEGRATIONS } from "@/lib/mock-data";

const CATEGORIES = Array.from(new Set(INTEGRATIONS.map((i) => i.category)));

export default function IntegrationsPage() {
  const [connected, setConnected] = React.useState(
    new Set(INTEGRATIONS.filter((i) => i.connected).map((i) => i.name))
  );

  function toggle(name: string) {
    setConnected((prev) => {
      const next = new Set(prev);
      if (next.has(name)) {
        next.delete(name);
        toast.message(`${name} disconnected`);
      } else {
        next.add(name);
        toast.success(`${name} connected`);
      }
      return next;
    });
  }

  return (
    <div>
      <PageHeader title="Integrations" description="Connect the tools you already use for publishing, commerce, and storage." />

      {CATEGORIES.map((cat) => (
        <div key={cat} className="mb-8">
          <p className="mb-3 text-sm font-semibold tracking-wide text-muted-foreground uppercase">{cat}</p>
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {INTEGRATIONS.filter((i) => i.category === cat).map((i) => (
              <Card key={i.name} className="flex items-center gap-3 p-4">
                <span className="flex size-10 items-center justify-center rounded-xl bg-secondary text-xl">{i.emoji}</span>
                <div className="min-w-0 flex-1">
                  <p className="text-sm font-medium">{i.name}</p>
                  {connected.has(i.name) && <Badge variant="success" className="mt-0.5">Connected</Badge>}
                </div>
                <Switch checked={connected.has(i.name)} onCheckedChange={() => toggle(i.name)} />
              </Card>
            ))}
          </div>
        </div>
      ))}
    </div>
  );
}
