import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "ShortsForge",
  description: "AI-powered YouTube Shorts studio",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className="dark">
      <body className="min-h-screen bg-base-950 text-gray-100 antialiased">{children}</body>
    </html>
  );
}
