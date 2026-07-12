"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { Mail } from "lucide-react";
import { AuthShell } from "@/components/marketing/auth-shell";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Separator } from "@/components/ui/separator";

export default function SignInPage() {
  const router = useRouter();

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    router.push("/dashboard");
  }

  return (
    <AuthShell
      title="Welcome back"
      subtitle="Sign in to keep shipping winning ads."
      footer={
        <>
          Don&apos;t have an account?{" "}
          <Link href="/sign-up" className="font-medium text-primary hover:underline">
            Start free
          </Link>
        </>
      }
    >
      <Button variant="outline" className="w-full" onClick={() => router.push("/dashboard")}>
        <Mail className="size-4" /> Continue with SSO
      </Button>
      <div className="my-5 flex items-center gap-3">
        <Separator className="flex-1" />
        <span className="text-xs text-muted-foreground">or</span>
        <Separator className="flex-1" />
      </div>
      <form onSubmit={handleSubmit} className="space-y-4">
        <div className="space-y-1.5">
          <Label htmlFor="email">Email</Label>
          <Input id="email" type="email" placeholder="you@brand.com" defaultValue="love.lindberg10@gmail.com" required />
        </div>
        <div className="space-y-1.5">
          <Label htmlFor="password">Password</Label>
          <Input id="password" type="password" placeholder="••••••••" required />
        </div>
        <Button type="submit" variant="gradient" className="w-full">
          Sign in
        </Button>
      </form>
    </AuthShell>
  );
}
