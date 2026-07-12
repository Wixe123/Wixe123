import Link from "next/link";
import { Logo } from "@/components/layout/logo";

const COLUMNS = [
  {
    title: "Product",
    links: [
      { label: "Script generator", href: "#product" },
      { label: "AI avatars", href: "#product" },
      { label: "Viral optimizer", href: "#product" },
      { label: "Pricing", href: "#pricing" },
    ],
  },
  {
    title: "Use cases",
    links: [
      { label: "Shopify stores", href: "#" },
      { label: "TikTok Shop sellers", href: "#" },
      { label: "Marketing agencies", href: "#" },
      { label: "Amazon sellers", href: "#" },
    ],
  },
  {
    title: "Company",
    links: [
      { label: "About", href: "#" },
      { label: "Affiliate program", href: "#" },
      { label: "Careers", href: "#" },
      { label: "Contact", href: "#" },
    ],
  },
  {
    title: "Legal",
    links: [
      { label: "Privacy", href: "#" },
      { label: "Terms", href: "#" },
      { label: "GDPR", href: "#" },
    ],
  },
];

export function Footer() {
  return (
    <footer className="border-t border-border/60 bg-secondary/20">
      <div className="mx-auto max-w-7xl px-4 py-16 sm:px-6 lg:px-8">
        <div className="grid grid-cols-2 gap-8 md:grid-cols-6">
          <div className="col-span-2">
            <Logo />
            <p className="mt-3 max-w-xs text-sm text-muted-foreground">
              Premium AI UGC ad studio for brands, agencies, and creators who need
              ads that convert — not just ads that look AI-generated.
            </p>
          </div>
          {COLUMNS.map((col) => (
            <div key={col.title}>
              <p className="text-sm font-semibold">{col.title}</p>
              <ul className="mt-3 space-y-2.5">
                {col.links.map((l) => (
                  <li key={l.label}>
                    <Link href={l.href} className="text-sm text-muted-foreground hover:text-foreground">
                      {l.label}
                    </Link>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>
        <div className="mt-12 flex flex-col items-center justify-between gap-4 border-t border-border/60 pt-6 sm:flex-row">
          <p className="text-xs text-muted-foreground">
            © {new Date().getFullYear()} CreatorAI UGC Studio. All rights reserved.
          </p>
          <p className="text-xs text-muted-foreground">Made for brands that ship fast.</p>
        </div>
      </div>
    </footer>
  );
}
