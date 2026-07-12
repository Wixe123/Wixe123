// AI service layer for CreatorAI UGC Studio.
//
// Every function here first checks for a real provider key (OPENAI_API_KEY,
// ELEVENLABS_API_KEY, HEYGEN_API_KEY, FAL_KEY, RUNWAY_API_KEY, REPLICATE_API_TOKEN).
// When a key is present, swap the body of the matching `callX` function for a real
// SDK/fetch call to that provider. When it's absent (default in this demo build),
// each function falls back to a fast, realistic mock so the whole product is
// explorable without any credentials configured.
import { HOOKS, VOICES } from "@/lib/mock-data";
import { sleep, randomBetween } from "@/lib/utils";

export function hasProviderKey(name: string): boolean {
  return Boolean(process.env[name]);
}

export type ProductInfo = {
  title: string;
  brand: string;
  price: string;
  description: string;
  features: string[];
  benefits: string[];
  colors: string[];
  rating: number;
  reviewCount: number;
  targetAudience: string[];
  competitors: string[];
  sourceType: "image" | "video" | "amazon" | "shopify" | "website" | "text" | "pdf";
};

const PRODUCT_TEMPLATES: Omit<ProductInfo, "sourceType">[] = [
  {
    title: "GlowSerum Vitamin C Brightening Serum",
    brand: "Loop Skincare",
    price: "$34.00",
    description:
      "A lightweight vitamin C serum that visibly brightens skin tone and smooths texture in 14 days.",
    features: ["20% Vitamin C complex", "Hyaluronic acid", "Vegan & cruelty-free", "30ml glass bottle"],
    benefits: ["Brighter, more even skin tone", "Reduces the look of fine lines", "Non-greasy, fast absorption"],
    colors: ["Amber", "Clear"],
    rating: 4.7,
    reviewCount: 2318,
    targetAudience: ["Beauty enthusiasts", "Busy moms", "Professionals"],
    competitors: ["The Ordinary", "Drunk Elephant", "TruSkin"],
  },
  {
    title: "TrailRunner Pro Running Shoes",
    brand: "Fetch Supply Co.",
    price: "$118.00",
    description: "Cushioned trail running shoes engineered for grip, breathability, and all-day comfort.",
    features: ["Carbon-infused midsole", "Recycled mesh upper", "4mm lug outsole", "Available in 6 colors"],
    benefits: ["Better grip on uneven terrain", "Reduces joint impact on long runs", "Breathable in hot weather"],
    colors: ["Slate", "Coral", "Black/Volt"],
    rating: 4.8,
    reviewCount: 4021,
    targetAudience: ["Runners", "Gym lovers", "Travelers"],
    competitors: ["Hoka", "Brooks", "Salomon"],
  },
  {
    title: "PupBowl Slow Feeder Dog Bowl",
    brand: "Fetch Pets",
    price: "$22.00",
    description: "A ridged slow-feeder bowl that reduces bloating and slows down fast eaters by up to 10x.",
    features: ["Food-grade silicone", "Non-slip base", "Dishwasher safe", "3 sizes"],
    benefits: ["Slows eating to prevent bloating", "Reduces vomiting after meals", "Easy to clean"],
    colors: ["Sage", "Charcoal", "Terracotta"],
    rating: 4.6,
    reviewCount: 8710,
    targetAudience: ["Dog owners", "Pet owners", "Busy moms"],
    competitors: ["Outward Hound", "UPSKY", "Neater Pet Brands"],
  },
];

function pickTemplate(seed: string): Omit<ProductInfo, "sourceType"> {
  const idx = Math.abs(hashString(seed)) % PRODUCT_TEMPLATES.length;
  return PRODUCT_TEMPLATES[idx];
}

function hashString(str: string): number {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    hash = (hash << 5) - hash + str.charCodeAt(i);
    hash |= 0;
  }
  return hash;
}

export async function scrapeProduct(
  input: string,
  sourceType: ProductInfo["sourceType"]
): Promise<ProductInfo> {
  await sleep(randomBetween(700, 1400));
  const template = pickTemplate(input || sourceType);
  return { ...template, sourceType };
}

export type Script = {
  id: string;
  hook: string;
  body: string;
  cta: string;
  tone: string;
  durationSec: number;
  qualityScore: number;
  tags: string[];
};

function buildScript(
  id: string,
  hook: string,
  product: ProductInfo,
  audience: string,
  objective: string
): Script {
  const body = [
    `If you're like most ${audience.toLowerCase()}, you've probably struggled with this before.`,
    `That's exactly why I started using ${product.title}.`,
    `${product.benefits[0]}. ${product.benefits[1] ?? ""}`.trim(),
    `Over ${product.reviewCount.toLocaleString()} people are already rating it ${product.rating}/5.`,
  ].join(" ");
  const ctaByObjective: Record<string, string> = {
    Sales: `It's on sale right now at ${product.price} — link is in my bio before it sells out.`,
    "Brand awareness": `Follow along, I'm going to keep testing ${product.brand} stuff for you.`,
    "Product launch": `${product.brand} just dropped this and I got early access — go check it out.`,
    "Lead generation": `Drop your email in the link below and they'll send you 15% off.`,
    "App installs": `Download the app from the link to grab this deal before it's gone.`,
    "Email signup": `Sign up through the link to get notified before the next restock.`,
    "Website traffic": `Head to their site through the link, you'll see exactly what I mean.`,
    Retargeting: `You've seen this before — this is your sign to finally grab one.`,
    "Holiday campaign": `This is going straight on my gift list this year — link's below.`,
  };
  const cta = ctaByObjective[objective] ?? `Link is in my bio if you want to try it.`;
  const qualityScore = randomBetween(74, 97);
  return {
    id,
    hook,
    body,
    cta,
    tone: ["Conversational", "Excited", "Calm & trustworthy", "Energetic"][randomBetween(0, 3)],
    durationSec: randomBetween(18, 42),
    qualityScore,
    tags: ["Pain point", "Social proof", "Urgency", "FOMO"].filter(() => Math.random() > 0.35),
  };
}

export async function generateScripts(params: {
  product: ProductInfo;
  audience: string;
  platform: string;
  objective: string;
  count?: number;
}): Promise<Script[]> {
  await sleep(randomBetween(1200, 2200));
  const { product, audience, objective, count = 5 } = params;
  const shuffledHooks = [...HOOKS].sort(() => Math.random() - 0.5).slice(0, count);
  return shuffledHooks.map((hook, i) =>
    buildScript(`script-${i + 1}`, hook, product, audience, objective)
  );
}

export type ViralScore = {
  hookStrength: number;
  retentionPrediction: number;
  watchTimePrediction: number;
  scrollStoppingScore: number;
  ctrPrediction: number;
  engagementPrediction: number;
  viralityScore: number;
  adQualityScore: number;
  suggestions: string[];
};

const SUGGESTIONS_POOL = [
  "Open with the pain point before the product name — you're losing the first 2 seconds.",
  "Add a pattern interrupt in the first line (a bold claim or visual surprise).",
  "Show the product in-hand within the first 3 seconds to boost retention.",
  "Tighten the middle section — aim for under 30 seconds for TikTok.",
  "Add a number or stat for authority (e.g. review count, % improvement).",
  "End with urgency or scarcity language to lift CTR.",
  "Use a more conversational, less scripted tone in the first line.",
  "Add a jump cut right after the hook to re-capture attention.",
  "Mention the audience directly (\"if you're a busy mom...\") to boost relevance.",
  "Close on the CTA within the last 3 seconds, not before.",
];

export async function scoreVirality(script: { hook: string; body: string; cta: string }): Promise<ViralScore> {
  await sleep(randomBetween(500, 1000));
  const base = 60 + Math.min(30, script.hook.length % 30) + randomBetween(0, 10);
  const clamp = (n: number) => Math.max(40, Math.min(99, n));
  const hookStrength = clamp(base + randomBetween(-5, 12));
  const retentionPrediction = clamp(base + randomBetween(-10, 8));
  const watchTimePrediction = clamp(base + randomBetween(-8, 10));
  const scrollStoppingScore = clamp(base + randomBetween(-4, 14));
  const ctrPrediction = clamp(base + randomBetween(-12, 6));
  const engagementPrediction = clamp(base + randomBetween(-6, 9));
  const viralityScore = Math.round(
    (hookStrength + retentionPrediction + scrollStoppingScore + ctrPrediction) / 4
  );
  const adQualityScore = Math.round(
    (viralityScore + watchTimePrediction + engagementPrediction) / 3
  );
  const suggestions = [...SUGGESTIONS_POOL].sort(() => Math.random() - 0.5).slice(0, 3);
  return {
    hookStrength,
    retentionPrediction,
    watchTimePrediction,
    scrollStoppingScore,
    ctrPrediction,
    engagementPrediction,
    viralityScore,
    adQualityScore,
    suggestions,
  };
}

export type ThumbnailStyle =
  | "Bold" | "Luxury" | "Minimal" | "TikTok" | "YouTube" | "High CTR" | "Reaction face" | "Clean" | "Product focus";

export async function generateThumbnails(productTitle: string, count = 10): Promise<
  { id: string; style: ThumbnailStyle; gradient: string; ctrEstimate: number }[]
> {
  await sleep(randomBetween(900, 1600));
  const styles: ThumbnailStyle[] = [
    "Bold", "Luxury", "Minimal", "TikTok", "YouTube", "High CTR", "Reaction face", "Clean", "Product focus", "Bold",
  ];
  const gradients = [
    "from-violet-500 to-fuchsia-500", "from-amber-400 to-rose-500", "from-sky-500 to-indigo-500",
    "from-emerald-500 to-teal-400", "from-rose-500 to-orange-400", "from-indigo-500 to-purple-500",
  ];
  return Array.from({ length: count }).map((_, i) => ({
    id: `thumb-${i + 1}`,
    style: styles[i % styles.length],
    gradient: gradients[i % gradients.length],
    ctrEstimate: randomBetween(4, 18),
  }));
}

export type CopyChannel =
  | "TikTok caption" | "Instagram caption" | "Facebook caption" | "Product description"
  | "Email subject" | "Google Ads headline" | "Meta Ads primary text" | "Pinterest description" | "SEO title";

export async function generateCopy(product: string, channel: CopyChannel): Promise<string[]> {
  await sleep(randomBetween(500, 1100));
  const templates: Record<CopyChannel, string[]> = {
    "TikTok caption": [
      `POV: you finally tried ${product} 🫶 #tiktokmademebuyit`,
      `okay but why did nobody tell me about ${product} sooner`,
      `the ${product} hype is actually real, I tested it for a week`,
    ],
    "Instagram caption": [
      `The one thing that's been living in my routine lately: ${product} ✨`,
      `Not me becoming obsessed with ${product}... link in bio`,
      `Real talk — ${product} earned its spot on my shelf.`,
    ],
    "Facebook caption": [
      `We asked 500 customers what changed their routine. #1 answer: ${product}.`,
      `${product} is having a moment — here's why.`,
    ],
    "Product description": [
      `${product} is designed for people who want results without the guesswork — engineered, tested, and loved by thousands.`,
    ],
    "Email subject": [`You asked, we shipped: ${product} is back 👀`, `Last chance: ${product} restock ends tonight`],
    "Google Ads headline": [`${product} — Shop Bestsellers`, `${product} | Free Shipping Today`],
    "Meta Ads primary text": [
      `Stop scrolling — this is the ${product} everyone's talking about. Rated 4.8/5 by thousands of customers.`,
    ],
    "Pinterest description": [`${product} inspiration board — save this for later 📌`],
    "SEO title": [`${product}: Reviews, Pricing & Where to Buy in 2026`],
  };
  return templates[channel] ?? [`${product} — discover why everyone's switching.`];
}

export async function generateVoicePreview(voiceId: string): Promise<{ url: string; text: string }> {
  await sleep(randomBetween(400, 900));
  const voice = VOICES.find((v) => v.id === voiceId) ?? VOICES[0];
  return { url: "#", text: voice.sampleLine };
}

export type ABVariant = {
  id: string;
  label: "A" | "B" | "C";
  hook: string;
  voice: string;
  background: string;
  cta: string;
  predictedCtr: number;
};

export async function generateABVariants(product: string): Promise<ABVariant[]> {
  await sleep(randomBetween(900, 1500));
  const labels: ("A" | "B" | "C")[] = ["A", "B", "C"];
  const backgrounds = ["Kitchen", "Bedroom", "Outdoors", "Studio", "Car", "Cafe"];
  return labels.map((label, i) => ({
    id: `variant-${label}`,
    label,
    hook: HOOKS[randomBetween(0, HOOKS.length - 1)],
    voice: VOICES[randomBetween(0, VOICES.length - 1)].name,
    background: backgrounds[randomBetween(0, backgrounds.length - 1)],
    cta:
      i === 0
        ? `Shop ${product} now — link in bio`
        : i === 1
          ? `Get 20% off ${product} today only`
          : "See why everyone's switching",
    predictedCtr: randomBetween(3, 16) / 10 + 2,
  }));
}
