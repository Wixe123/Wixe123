import { NextRequest, NextResponse } from "next/server";
import { scrapeProduct, hasProviderKey, type ProductInfo } from "@/lib/ai/engine";

export async function POST(req: NextRequest) {
  const body = await req.json().catch(() => ({}));
  const input: string = body.input ?? "";
  const sourceType: ProductInfo["sourceType"] = body.sourceType ?? "text";

  if (!input) {
    return NextResponse.json({ error: "Missing product input" }, { status: 400 });
  }

  // Production: route to a scraping worker (Amazon/Shopify APIs, Playwright, or
  // an LLM extraction call gated behind OPENAI_API_KEY). Demo mode falls back
  // to a deterministic mock so the wizard works without credentials.
  const usingLiveProvider = hasProviderKey("OPENAI_API_KEY");
  const product = await scrapeProduct(input, sourceType);

  return NextResponse.json({ product, live: usingLiveProvider });
}
