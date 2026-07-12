"use client";

import * as React from "react";
import { usePathname } from "next/navigation";
import { motion, AnimatePresence } from "framer-motion";
import { Sparkles, X, Send, Wand2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { cn, sleep } from "@/lib/utils";

type Message = { id: string; role: "user" | "assistant"; text: string };

const SUGGESTIONS = [
  "How do I improve conversions?",
  "Write another hook",
  "Make it funnier",
  "Make it luxury",
  "Target Gen Z",
  "Shorten to 15 seconds",
  "Rewrite for TikTok",
];

const RESPONSES: Record<string, string> = {
  "How do I improve conversions?":
    "Three quick wins: 1) open with the pain point, not the product name, 2) add a real number for authority (reviews, % improvement), 3) put urgency in the last 3 seconds. Want me to rewrite your current script with these?",
  "Write another hook":
    "Try: \"I almost didn't post this because it feels like cheating.\" — pattern interrupts like this outperform generic openers by ~18% in our data.",
  "Make it funnier":
    "Add a self-deprecating beat before the reveal, e.g. \"I've bought every fix on the internet, this is the first one that actually worked.\" Deadpan delivery lands best.",
  "Make it luxury":
    "Slow the pacing by ~20%, swap exclamation points for understatement, and use a calm/luxury voice preset. I'd also darken the background to Studio or Apartment.",
  "Target Gen Z":
    "Cut the intro, start mid-action, use lowercase captions, and lean into a single relatable pain point instead of a feature list.",
  "Shorten to 15 seconds":
    "Drop the story beat, keep hook → 1 benefit → CTA. I can trim your current script to ~15s — want me to apply it?",
  "Rewrite for TikTok":
    "TikTok rewards a hook in the first 1.5 seconds and native, unscripted phrasing. I'd cut any brand-speak and add one on-screen text overlay for the hook line.",
};

function assistantReply(input: string): string {
  const match = Object.keys(RESPONSES).find(
    (k) => k.toLowerCase() === input.toLowerCase()
  );
  if (match) return RESPONSES[match];
  return "Got it — I'd focus on tightening your hook and adding one concrete proof point (a number, review count, or before/after). Want me to draft a revised version?";
}

export function AIChatWidget() {
  const pathname = usePathname();
  const [open, setOpen] = React.useState(false);
  const [input, setInput] = React.useState("");
  const [typing, setTyping] = React.useState(false);
  const [messages, setMessages] = React.useState<Message[]>([
    {
      id: "welcome",
      role: "assistant",
      text: "Hey! I'm your built-in marketing expert. Ask me to punch up a hook, shift the tone, or target a new audience.",
    },
  ]);
  const scrollRef = React.useRef<HTMLDivElement>(null);

  async function send(text: string) {
    if (!text.trim()) return;
    const userMsg: Message = { id: crypto.randomUUID(), role: "user", text };
    setMessages((m) => [...m, userMsg]);
    setInput("");
    setTyping(true);
    await sleep(700 + Math.random() * 700);
    setTyping(false);
    setMessages((m) => [
      ...m,
      { id: crypto.randomUUID(), role: "assistant", text: assistantReply(text) },
    ]);
  }

  React.useEffect(() => {
    scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight, behavior: "smooth" });
  }, [messages, typing]);

  if (pathname === "/" || pathname?.startsWith("/sign-")) return null;

  return (
    <div className="fixed right-4 bottom-4 z-50 sm:right-6 sm:bottom-6">
      <AnimatePresence>
        {open && (
          <motion.div
            initial={{ opacity: 0, y: 16, scale: 0.96 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: 16, scale: 0.96 }}
            transition={{ duration: 0.18 }}
            className="glass mb-3 flex h-[480px] w-[340px] flex-col overflow-hidden rounded-2xl shadow-2xl sm:w-[380px]"
          >
            <div className="flex items-center gap-2 border-b border-border/60 px-4 py-3">
              <span className="flex size-8 items-center justify-center rounded-lg bg-[linear-gradient(135deg,var(--gradient-1),var(--gradient-2))] text-white">
                <Wand2 className="size-4" />
              </span>
              <div className="flex-1">
                <p className="text-sm font-semibold">Marketing Assistant</p>
                <p className="text-xs text-muted-foreground">Always on, always honest</p>
              </div>
              <Button variant="ghost" size="icon-sm" onClick={() => setOpen(false)}>
                <X className="size-4" />
              </Button>
            </div>

            <div ref={scrollRef} className="flex-1 space-y-3 overflow-y-auto px-4 py-3 no-scrollbar">
              {messages.map((m) => (
                <div
                  key={m.id}
                  className={cn("flex", m.role === "user" ? "justify-end" : "justify-start")}
                >
                  <div
                    className={cn(
                      "max-w-[85%] rounded-2xl px-3.5 py-2 text-sm leading-relaxed",
                      m.role === "user"
                        ? "bg-primary text-primary-foreground rounded-br-sm"
                        : "bg-secondary text-secondary-foreground rounded-bl-sm"
                    )}
                  >
                    {m.text}
                  </div>
                </div>
              ))}
              {typing && (
                <div className="flex justify-start">
                  <div className="flex gap-1 rounded-2xl rounded-bl-sm bg-secondary px-3.5 py-3">
                    {[0, 1, 2].map((i) => (
                      <span
                        key={i}
                        className="size-1.5 animate-bounce rounded-full bg-muted-foreground"
                        style={{ animationDelay: `${i * 0.12}s` }}
                      />
                    ))}
                  </div>
                </div>
              )}
            </div>

            <div className="border-t border-border/60 p-3">
              <div className="mb-2 flex flex-wrap gap-1.5">
                {SUGGESTIONS.slice(0, 3).map((s) => (
                  <button
                    key={s}
                    onClick={() => send(s)}
                    className="rounded-full border border-border bg-background px-2.5 py-1 text-[11px] text-muted-foreground hover:text-foreground hover:bg-secondary"
                  >
                    {s}
                  </button>
                ))}
              </div>
              <form
                onSubmit={(e) => {
                  e.preventDefault();
                  send(input);
                }}
                className="flex items-center gap-2"
              >
                <input
                  value={input}
                  onChange={(e) => setInput(e.target.value)}
                  placeholder="Ask anything about your ad…"
                  className="h-9 flex-1 rounded-xl border border-input bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring"
                />
                <Button type="submit" size="icon-sm" variant="gradient">
                  <Send className="size-3.5" />
                </Button>
              </form>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      <motion.button
        whileHover={{ scale: 1.05 }}
        whileTap={{ scale: 0.95 }}
        onClick={() => setOpen((o) => !o)}
        className="flex size-14 items-center justify-center rounded-full bg-[linear-gradient(135deg,var(--gradient-1),var(--gradient-2))] text-white shadow-[0_10px_30px_-8px_var(--gradient-1)]"
        aria-label="Open AI assistant"
      >
        {open ? <X className="size-5" /> : <Sparkles className="size-5" />}
      </motion.button>
    </div>
  );
}
