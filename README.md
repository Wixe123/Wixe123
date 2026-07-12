# CreatorAI UGC Studio

A premium AI-powered SaaS platform for generating realistic, conversion-optimized
UGC-style marketing videos — from product link to finished ad in under 3 minutes.

## Stack

- **Frontend**: Next.js 16 (App Router), TypeScript, Tailwind CSS v4, Framer Motion
- **UI kit**: hand-built shadcn-style primitives on Radix UI (`components/ui`)
- **Charts**: Recharts
- **AI service layer**: `lib/ai/engine.ts` — provider-aware functions for script
  generation, product scraping, viral scoring, thumbnails, copy, and A/B variants

## Demo mode

The app runs fully standalone with zero configuration. Every AI capability
(`lib/ai/engine.ts`, `app/api/generate-scripts`, `app/api/scrape-product`) checks
for a real provider key (`OPENAI_API_KEY`, `ELEVENLABS_API_KEY`, `HEYGEN_API_KEY`,
etc.) and falls back to a fast, realistic mock when none is set — so the entire
product, including the "product link → finished ad" wizard, is explorable without
any credentials. See `.env.example` for the full list of provider variables to
wire up real generation.

## Getting started

```bash
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000). The marketing site is at `/`;
the app lives under `/dashboard` (reachable via `/sign-up` or `/sign-in` — both are
demo auth screens that go straight to the dashboard).

## Structure

- `app/` — marketing site, auth screens, and the `/dashboard/*` app (projects,
  scripts, avatars, voices, video studio, viral optimizer, thumbnails, copywriter,
  A/B testing, brand kit, team, integrations, billing, settings)
- `components/ui/` — design system primitives
- `components/marketing/`, `components/dashboard/`, `components/wizard/` — page-level building blocks
- `lib/mock-data.ts` — demo data (avatars, voices, pricing, testimonials, etc.)
- `lib/ai/engine.ts` — the AI/provider service layer

## Scripts

- `npm run dev` — start the dev server
- `npm run build` — production build
- `npm run lint` — ESLint
