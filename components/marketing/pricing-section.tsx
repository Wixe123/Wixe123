"use client";

import * as React from "react";
import Link from "next/link";
import { motion } from "framer-motion";
import { Check } from "lucide-react";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Switch } from "@/components/ui/switch";
import { PRICING_PLANS } from "@/lib/mock-data";
import { cn } from "@/lib/utils";

export function PricingSection() {
  const [annual, setAnnual] = React.useState(false);
  return (
    <section id="pricing" className="mx-auto max-w-7xl px-4 py-24 sm:px-6 lg:px-8">
      <div className="mx-auto max-w-2xl text-center">
        <h2 className="font-display text-3xl font-bold tracking-tight sm:text-4xl">
          Simple pricing that scales with output
        </h2>
        <p className="mt-4 text-muted-foreground">
          Credits roll over on Pro and Agency. Cancel anytime.
        </p>
        <div className="mt-6 flex items-center justify-center gap-3">
          <span className={cn("text-sm", !annual && "font-semibold")}>Monthly</span>
          <Switch checked={annual} onCheckedChange={setAnnual} />
          <span className={cn("text-sm", annual && "font-semibold")}>
            Annual <Badge variant="success" className="ml-1">Save 20%</Badge>
          </span>
        </div>
      </div>

      <div className="mt-12 grid grid-cols-1 gap-5 md:grid-cols-2 lg:grid-cols-4">
        {PRICING_PLANS.map((plan, i) => {
          const price = plan.price === 0 ? null : annual ? Math.round(plan.price * 0.8) : plan.price;
          return (
            <motion.div
              key={plan.id}
              initial={{ opacity: 0, y: 16 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, margin: "-40px" }}
              transition={{ duration: 0.4, delay: i * 0.06 }}
            >
              <Card
                className={cn(
                  "flex h-full flex-col p-6",
                  plan.highlight && "border-primary/60 shadow-[0_0_0_1px_var(--primary),0_20px_40px_-20px_var(--primary)]"
                )}
              >
                {plan.highlight && (
                  <Badge variant="gradient" className="mb-3 w-fit">Most popular</Badge>
                )}
                <h3 className="font-display text-lg font-semibold">{plan.name}</h3>
                <p className="mt-1 text-sm text-muted-foreground">{plan.description}</p>
                <div className="mt-5 flex items-baseline gap-1">
                  {price === null ? (
                    <span className="font-display text-3xl font-bold">Custom</span>
                  ) : (
                    <>
                      <span className="font-display text-3xl font-bold">${price}</span>
                      <span className="text-sm text-muted-foreground">/mo</span>
                    </>
                  )}
                </div>
                {plan.credits > 0 && (
                  <p className="mt-1 text-xs text-muted-foreground">{plan.credits} video credits / mo</p>
                )}
                <Button
                  asChild
                  variant={plan.highlight ? "gradient" : "outline"}
                  className="mt-6 w-full"
                >
                  <Link href="/sign-up">{plan.cta}</Link>
                </Button>
                <ul className="mt-6 space-y-2.5">
                  {plan.features.map((f) => (
                    <li key={f} className="flex items-start gap-2 text-sm">
                      <Check className="mt-0.5 size-3.5 shrink-0 text-primary" />
                      <span className="text-muted-foreground">{f}</span>
                    </li>
                  ))}
                </ul>
              </Card>
            </motion.div>
          );
        })}
      </div>
    </section>
  );
}
