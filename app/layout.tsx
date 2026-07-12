import type { Metadata } from "next";
import { Plus_Jakarta_Sans, Inter } from "next/font/google";
import "./globals.css";
import { ThemeProvider } from "@/components/theme-provider";
import { Toaster } from "sonner";
import { AIChatWidget } from "@/components/chat/ai-chat-widget";

const fontSans = Inter({
  variable: "--font-sans",
  subsets: ["latin"],
});

const fontDisplay = Plus_Jakarta_Sans({
  variable: "--font-display",
  subsets: ["latin"],
  weight: ["500", "600", "700", "800"],
});

export const metadata: Metadata = {
  title: "CreatorAI UGC Studio — AI UGC ads that convert",
  description:
    "Create realistic, conversion-optimized UGC ad videos in under 3 minutes. AI avatars, natural voices, viral hooks, and A/B testing built for Shopify, TikTok Shop, and DTC brands.",
  metadataBase: new URL("https://creatorai-ugc.studio"),
  openGraph: {
    title: "CreatorAI UGC Studio",
    description:
      "AI-generated UGC ads that look like real people, not AI. Ship winning creatives in minutes.",
    type: "website",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="en"
      suppressHydrationWarning
      className={`${fontSans.variable} ${fontDisplay.variable} h-full antialiased`}
    >
      <body className="min-h-full flex flex-col">
        <ThemeProvider
          attribute="data-theme"
          defaultTheme="dark"
          enableSystem
          disableTransitionOnChange
        >
          {children}
          <AIChatWidget />
          <Toaster richColors position="top-right" theme="system" />
        </ThemeProvider>
      </body>
    </html>
  );
}
