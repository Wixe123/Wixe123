// Centralized demo/mock data for CreatorAI UGC Studio.
// In production, these are replaced by Supabase queries + the lib/ai/* service layer.

export type Avatar = {
  id: string;
  name: string;
  gender: "Female" | "Male";
  age: "Teen" | "Young Adult" | "Adult" | "Senior";
  ethnicity: string;
  category:
    | "Lifestyle"
    | "Fitness"
    | "Beauty"
    | "Business"
    | "Tech"
    | "Luxury"
    | "Parents"
    | "Creators"
    | "Doctors";
  room:
    | "Kitchen"
    | "Bedroom"
    | "Office"
    | "Living Room"
    | "Gym"
    | "Cafe"
    | "Car"
    | "Outdoors"
    | "Apartment"
    | "Studio";
  accent: "US" | "UK" | "Australian" | "Canadian" | "Irish" | "Indian";
  gradient: string;
  emoji: string;
};

const ETHNICITIES = ["Caucasian", "Black", "Latina/Latino", "Asian", "Middle Eastern", "South Asian", "Mixed"];
const GRADIENTS = [
  "from-violet-500 to-fuchsia-500",
  "from-sky-500 to-indigo-500",
  "from-rose-500 to-orange-400",
  "from-emerald-500 to-teal-400",
  "from-amber-400 to-rose-500",
  "from-indigo-500 to-purple-500",
  "from-pink-500 to-rose-400",
  "from-teal-400 to-cyan-500",
];
const FEMALE_NAMES = [
  "Ava", "Mia", "Sophia", "Isabella", "Chloe", "Layla", "Zoe", "Priya", "Naomi", "Elena",
  "Grace", "Amara", "Jade", "Ruby", "Nina", "Camila", "Freya", "Aaliyah", "Ines", "Talia",
];
const MALE_NAMES = [
  "Ethan", "Liam", "Marcus", "Noah", "Kai", "Diego", "Omar", "Jordan", "Felix", "Adrian",
  "Theo", "Malik", "Lucas", "Ravi", "Jesse", "Mason", "Elijah", "Zion", "Dante", "Miles",
];
const CATEGORIES: Avatar["category"][] = [
  "Lifestyle", "Fitness", "Beauty", "Business", "Tech", "Luxury", "Parents", "Creators", "Doctors",
];
const ROOMS: Avatar["room"][] = [
  "Kitchen", "Bedroom", "Office", "Living Room", "Gym", "Cafe", "Car", "Outdoors", "Apartment", "Studio",
];
const ACCENTS: Avatar["accent"][] = ["US", "UK", "Australian", "Canadian", "Irish", "Indian"];
const AGES: Avatar["age"][] = ["Teen", "Young Adult", "Adult", "Senior"];

function seededAvatars(count: number): Avatar[] {
  const list: Avatar[] = [];
  for (let i = 0; i < count; i++) {
    const isFemale = i % 2 === 0;
    const names = isFemale ? FEMALE_NAMES : MALE_NAMES;
    const name = names[i % names.length];
    list.push({
      id: `avatar-${i + 1}`,
      name,
      gender: isFemale ? "Female" : "Male",
      age: AGES[i % AGES.length],
      ethnicity: ETHNICITIES[i % ETHNICITIES.length],
      category: CATEGORIES[i % CATEGORIES.length],
      room: ROOMS[i % ROOMS.length],
      accent: ACCENTS[i % ACCENTS.length],
      gradient: GRADIENTS[i % GRADIENTS.length],
      emoji: isFemale ? "👩" : "👨",
    });
  }
  return list;
}

export const AVATARS: Avatar[] = seededAvatars(48);

export type Voice = {
  id: string;
  name: string;
  language: string;
  accent: string;
  gender: "Female" | "Male";
  emotion: string;
  sampleLine: string;
};

export const VOICES: Voice[] = [
  { id: "v1", name: "Harper", language: "English", accent: "US", gender: "Female", emotion: "Friendly", sampleLine: "Okay, I was NOT expecting this to work so well." },
  { id: "v2", name: "Oliver", language: "English", accent: "UK", gender: "Male", emotion: "Conversational", sampleLine: "Right, so I need to talk about this for a second." },
  { id: "v3", name: "Camila", language: "Spanish", accent: "US", gender: "Female", emotion: "Excited", sampleLine: "No puedo creer que esto realmente funcione." },
  { id: "v4", name: "Jasper", language: "English", accent: "Australian", gender: "Male", emotion: "Energetic", sampleLine: "Mate, I almost returned this — huge mistake avoided." },
  { id: "v5", name: "Freya", language: "English", accent: "Irish", gender: "Female", emotion: "Calm", sampleLine: "I wish someone had told me about this months ago." },
  { id: "v6", name: "Anaya", language: "Hindi", accent: "Indian", gender: "Female", emotion: "Luxury", sampleLine: "Yeh product literally meri routine badal diya." },
  { id: "v7", name: "Noah", language: "English", accent: "Canadian", gender: "Male", emotion: "Serious", sampleLine: "Nobody talks about this, and honestly, they should." },
  { id: "v8", name: "Elise", language: "French", accent: "US", gender: "Female", emotion: "Luxury brand", sampleLine: "Franchement, ce produit a changé mes matins." },
];

export const HOOKS = [
  "I honestly wasn't expecting this to work...",
  "If you struggle with this, watch till the end.",
  "This changed my mornings forever.",
  "I wish I found this sooner.",
  "I bought this so you don't have to.",
  "I almost returned this... here's why I didn't.",
  "Nobody talks about this, but they should.",
  "POV: you finally found the thing that works.",
  "This is not sponsored, I just need to talk about it.",
  "Okay wait, I need to be honest about this one.",
];

export const AUDIENCES = [
  "Busy moms", "Gym lovers", "Teenagers", "Runners", "Gamers", "Dog owners",
  "Entrepreneurs", "College students", "Travelers", "Beauty enthusiasts",
  "Pet owners", "Parents", "Professionals",
];

export const PLATFORMS = [
  { id: "tiktok", name: "TikTok", ratio: "9:16" },
  { id: "instagram", name: "Instagram", ratio: "9:16" },
  { id: "facebook", name: "Facebook", ratio: "1:1" },
  { id: "youtube", name: "YouTube Shorts", ratio: "9:16" },
  { id: "pinterest", name: "Pinterest", ratio: "9:16" },
  { id: "amazon", name: "Amazon", ratio: "16:9" },
  { id: "shopify", name: "Shopify", ratio: "1:1" },
  { id: "snapchat", name: "Snapchat", ratio: "9:16" },
];

export const OBJECTIVES = [
  "Sales", "Brand awareness", "Product launch", "Lead generation", "App installs",
  "Email signup", "Website traffic", "Retargeting", "Holiday campaign",
];

export type PricingPlan = {
  id: string;
  name: string;
  price: number;
  period: "mo";
  credits: number;
  description: string;
  features: string[];
  highlight?: boolean;
  cta: string;
};

export const PRICING_PLANS: PricingPlan[] = [
  {
    id: "starter",
    name: "Starter",
    price: 39,
    period: "mo",
    credits: 15,
    description: "Test the waters with a handful of high-quality UGC ads.",
    features: [
      "15 video credits / mo",
      "40+ AI avatars",
      "8 languages",
      "Auto captions & subtitles",
      "720p & 1080p export",
      "Email support",
    ],
    cta: "Start free trial",
  },
  {
    id: "pro",
    name: "Pro",
    price: 99,
    period: "mo",
    credits: 60,
    description: "For Shopify stores and creators shipping ads every week.",
    features: [
      "60 video credits / mo",
      "200+ AI avatars",
      "12 languages, 6 accents",
      "Viral optimization engine",
      "A/B testing (3 variants)",
      "4K export + brand kit",
      "Priority rendering",
    ],
    highlight: true,
    cta: "Start free trial",
  },
  {
    id: "agency",
    name: "Agency",
    price: 249,
    period: "mo",
    credits: 200,
    description: "Run UGC production for multiple clients from one workspace.",
    features: [
      "200 video credits / mo",
      "Unlimited avatars & voices",
      "Team seats + client portal",
      "White-label exports",
      "Approval workflows",
      "Dedicated success manager",
    ],
    cta: "Talk to sales",
  },
  {
    id: "enterprise",
    name: "Enterprise",
    price: 0,
    period: "mo",
    credits: 0,
    description: "Custom volume, SSO, and SLAs for large marketing teams.",
    features: [
      "Custom credit volume",
      "SSO / SAML",
      "Dedicated infrastructure",
      "Custom integrations",
      "99.9% uptime SLA",
      "Audit logs & permissions",
    ],
    cta: "Contact us",
  },
];

export const TESTIMONIALS = [
  {
    name: "Maren Coleman",
    role: "Founder, Loop Skincare",
    quote:
      "We replaced our entire UGC agency retainer with CreatorAI. Our hook rate went up 34% in the first month.",
    avatarEmoji: "🧴",
  },
  {
    name: "Devon Ashworth",
    role: "Growth Lead, Fetch Supply Co.",
    quote:
      "The scripts alone are worth the price. It writes hooks better than the freelancers we used to hire.",
    avatarEmoji: "📦",
  },
  {
    name: "Priya Nandan",
    role: "Media Buyer, Agency Nine",
    quote:
      "We run every client's ad through the viral optimizer before it ships. It's caught weak hooks every single time.",
    avatarEmoji: "📈",
  },
  {
    name: "Jonas Feld",
    role: "Founder, Kindred Coffee",
    quote:
      "Under 3 minutes is not marketing copy — it's real. We shipped 12 ad variants before lunch.",
    avatarEmoji: "☕",
  },
];

export const COMPARISON = [
  { feature: "Time to first ad", us: "< 3 min", others: "20–45 min" },
  { feature: "Script psychology built-in", us: true, others: false },
  { feature: "Viral optimization score", us: true, others: false },
  { feature: "A/B variant generation", us: true, others: "Limited" },
  { feature: "Brand kit auto-apply", us: true, others: false },
  { feature: "Native Shopify / Amazon scraping", us: true, others: "Partial" },
  { feature: "4K export", us: true, others: "Paid add-on" },
  { feature: "Team & client portal", us: true, others: "Agency tier only" },
];

export const FAQS = [
  {
    q: "Will these videos look like obvious AI ads?",
    a: "No — that's the entire point. CreatorAI is tuned for natural imperfections: blinking, breathing, micro pauses, and conversational pacing so the output reads as a real person talking, not a synthetic avatar reading a script.",
  },
  {
    q: "How fast can I actually go from product to finished ad?",
    a: "Paste a Shopify or Amazon link, pick an audience and platform, and CreatorAI scrapes the product details, writes 5 scripts, and renders your first video in under 3 minutes.",
  },
  {
    q: "Can I use my own brand voice and colors?",
    a: "Yes. Upload your logo, fonts, and brand colors once in your Brand Kit and every script, caption, and export automatically inherits them.",
  },
  {
    q: "Do you support languages besides English?",
    a: "CreatorAI supports 10 languages and 6 English accents, with more shipping every month based on customer requests.",
  },
  {
    q: "What happens when I run out of credits?",
    a: "You can upgrade instantly or buy a top-up pack. Credits roll over on Pro and Agency plans for up to 60 days.",
  },
  {
    q: "Can agencies manage multiple clients?",
    a: "The Agency plan includes unlimited folders, a client approval portal, and white-labeled exports so you can run production for every client from one workspace.",
  },
];

export type Project = {
  id: string;
  name: string;
  thumbnail: string;
  status: "Rendering" | "Ready" | "Draft" | "Failed";
  platform: string;
  audience: string;
  createdAt: string;
  viralScore: number;
  favorite: boolean;
  duration: string;
};

export const RECENT_PROJECTS: Project[] = [
  { id: "p1", name: "GlowSerum — Morning Routine Hook", thumbnail: "✨", status: "Ready", platform: "TikTok", audience: "Beauty enthusiasts", createdAt: "2h ago", viralScore: 91, favorite: true, duration: "0:28" },
  { id: "p2", name: "TrailRunner Shoes — Pain Point v2", thumbnail: "👟", status: "Ready", platform: "Instagram", audience: "Runners", createdAt: "5h ago", viralScore: 84, favorite: false, duration: "0:34" },
  { id: "p3", name: "PupBowl — Almost Returned It", thumbnail: "🐶", status: "Rendering", platform: "TikTok", audience: "Dog owners", createdAt: "12m ago", viralScore: 0, favorite: false, duration: "0:22" },
  { id: "p4", name: "FocusDesk — Entrepreneur Story", thumbnail: "🖥️", status: "Ready", platform: "YouTube Shorts", audience: "Entrepreneurs", createdAt: "1d ago", viralScore: 76, favorite: true, duration: "0:41" },
  { id: "p5", name: "SnoozeCloud Pillow — Nobody Talks About This", thumbnail: "🛏️", status: "Draft", platform: "Facebook", audience: "Busy moms", createdAt: "2d ago", viralScore: 0, favorite: false, duration: "—" },
  { id: "p6", name: "IronGrip Gloves — Gym FOMO", thumbnail: "🏋️", status: "Failed", platform: "TikTok", audience: "Gym lovers", createdAt: "3d ago", viralScore: 0, favorite: false, duration: "—" },
];

export const TOP_HOOKS = [
  { hook: "I bought this so you don't have to.", score: 94, uses: 812 },
  { hook: "I almost returned this... here's why I didn't.", score: 91, uses: 674 },
  { hook: "This changed my mornings forever.", score: 88, uses: 590 },
  { hook: "Nobody talks about this, but they should.", score: 85, uses: 512 },
  { hook: "I wish I found this sooner.", score: 83, uses: 468 },
];

export const INTEGRATIONS = [
  { name: "TikTok", category: "Publishing", emoji: "🎵", connected: true },
  { name: "Instagram", category: "Publishing", emoji: "📸", connected: true },
  { name: "Meta Ads", category: "Publishing", emoji: "📣", connected: false },
  { name: "YouTube", category: "Publishing", emoji: "▶️", connected: false },
  { name: "Shopify", category: "Commerce", emoji: "🛍️", connected: true },
  { name: "WooCommerce", category: "Commerce", emoji: "🧺", connected: false },
  { name: "Amazon", category: "Commerce", emoji: "📦", connected: true },
  { name: "Google Drive", category: "Storage", emoji: "📁", connected: false },
  { name: "Dropbox", category: "Storage", emoji: "🗂️", connected: false },
  { name: "Canva", category: "Design", emoji: "🎨", connected: false },
  { name: "Slack", category: "Workflow", emoji: "💬", connected: true },
  { name: "Zapier", category: "Workflow", emoji: "⚡", connected: false },
  { name: "Stripe", category: "Billing", emoji: "💳", connected: true },
  { name: "OpenAI", category: "AI Engine", emoji: "🧠", connected: true },
  { name: "ElevenLabs", category: "AI Engine", emoji: "🗣️", connected: true },
  { name: "Runway", category: "AI Engine", emoji: "🎬", connected: false },
  { name: "HeyGen", category: "AI Engine", emoji: "🧑‍🎤", connected: false },
  { name: "Replicate", category: "AI Engine", emoji: "🔁", connected: false },
  { name: "Fal", category: "AI Engine", emoji: "🌀", connected: false },
  { name: "Cloudinary", category: "Storage", emoji: "☁️", connected: true },
  { name: "Supabase", category: "Infrastructure", emoji: "🗄️", connected: true },
];

export const TEAM_MEMBERS = [
  { name: "Love Lindberg", email: "love.lindberg10@gmail.com", role: "Owner", avatarEmoji: "🧑‍💻", status: "Active" },
  { name: "Sasha Fields", email: "sasha@agencynine.co", role: "Editor", avatarEmoji: "🎬", status: "Active" },
  { name: "Marcus Bello", email: "marcus@agencynine.co", role: "Reviewer", avatarEmoji: "✅", status: "Invited" },
  { name: "Client — Loop Skincare", email: "team@loopskincare.com", role: "Client (view only)", avatarEmoji: "🧴", status: "Active" },
];

export const DASHBOARD_STATS = {
  videosCreated: 187,
  creditsRemaining: 42,
  creditsTotal: 60,
  downloads: 143,
  favorites: 21,
  estimatedRevenue: 18420,
  avgWatchTime: 21.4,
  avgOptimizationScore: 87,
};

export const WEEKLY_PERFORMANCE = [
  { day: "Mon", videos: 6, watchTime: 19 },
  { day: "Tue", videos: 9, watchTime: 22 },
  { day: "Wed", videos: 4, watchTime: 18 },
  { day: "Thu", videos: 12, watchTime: 25 },
  { day: "Fri", videos: 15, watchTime: 27 },
  { day: "Sat", videos: 8, watchTime: 23 },
  { day: "Sun", videos: 11, watchTime: 24 },
];

export const SCORE_BREAKDOWN = [
  { label: "Hook strength", value: 92 },
  { label: "Retention prediction", value: 84 },
  { label: "Scroll-stopping score", value: 88 },
  { label: "CTR prediction", value: 79 },
  { label: "Engagement prediction", value: 86 },
];
