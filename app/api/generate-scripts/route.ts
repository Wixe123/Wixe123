import { NextRequest, NextResponse } from "next/server";
import { generateScripts, hasProviderKey, type ProductInfo } from "@/lib/ai/engine";

export async function POST(req: NextRequest) {
  const body = await req.json().catch(() => ({}));
  const product: ProductInfo | undefined = body.product;
  const audience: string = body.audience ?? "Everyone";
  const platform: string = body.platform ?? "TikTok";
  const objective: string = body.objective ?? "Sales";

  if (!product) {
    return NextResponse.json({ error: "Missing product" }, { status: 400 });
  }

  // Production: call GPT-5.5 / Claude with a marketing-psychology system prompt
  // (hook, pattern interrupt, pain point, story, solution, social proof, CTA)
  // gated behind OPENAI_API_KEY / ANTHROPIC_API_KEY. Demo mode uses the local
  // template engine so scripts generate instantly with no credentials.
  const usingLiveProvider = hasProviderKey("OPENAI_API_KEY") || hasProviderKey("ANTHROPIC_API_KEY");
  const scripts = await generateScripts({ product, audience, platform, objective });

  return NextResponse.json({ scripts, live: usingLiveProvider });
}
