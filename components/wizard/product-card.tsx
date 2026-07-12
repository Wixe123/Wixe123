import { Star } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent } from "@/components/ui/card";
import type { ProductInfo } from "@/lib/ai/engine";

export function ProductCard({ product }: { product: ProductInfo }) {
  return (
    <Card>
      <CardContent className="p-5">
        <div className="flex flex-wrap items-start justify-between gap-2">
          <div>
            <p className="text-xs font-medium text-muted-foreground">{product.brand}</p>
            <h3 className="font-display text-lg font-semibold">{product.title}</h3>
          </div>
          <span className="font-display text-lg font-bold text-primary">{product.price}</span>
        </div>
        <p className="mt-2 text-sm text-muted-foreground">{product.description}</p>
        <div className="mt-2 flex items-center gap-1.5 text-sm">
          <div className="flex text-amber-400">
            {Array.from({ length: 5 }).map((_, i) => (
              <Star
                key={i}
                className={`size-3.5 ${i < Math.round(product.rating) ? "fill-current" : ""}`}
              />
            ))}
          </div>
          <span className="text-muted-foreground">
            {product.rating} ({product.reviewCount.toLocaleString()} reviews)
          </span>
        </div>

        <div className="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-2">
          <div>
            <p className="mb-1.5 text-xs font-semibold tracking-wide text-muted-foreground uppercase">
              Features
            </p>
            <div className="flex flex-wrap gap-1.5">
              {product.features.map((f) => (
                <Badge key={f} variant="secondary">{f}</Badge>
              ))}
            </div>
          </div>
          <div>
            <p className="mb-1.5 text-xs font-semibold tracking-wide text-muted-foreground uppercase">
              Benefits
            </p>
            <div className="flex flex-wrap gap-1.5">
              {product.benefits.map((b) => (
                <Badge key={b}>{b}</Badge>
              ))}
            </div>
          </div>
        </div>

        <div className="mt-4 flex flex-wrap gap-4 text-xs text-muted-foreground">
          <span>Colors: {product.colors.join(", ")}</span>
          <span>Competitors: {product.competitors.join(", ")}</span>
          <span>Suggested audience: {product.targetAudience.join(", ")}</span>
        </div>
      </CardContent>
    </Card>
  );
}
