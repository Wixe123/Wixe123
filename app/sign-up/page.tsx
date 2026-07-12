"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { Mail } from "lucide-react";
import { AuthShell } from "@/components/marketing/auth-shell";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Separator } from "@/components/ui/separator";

export default function SignUpPage() {
  const router = useRouter();

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    router.push("/dashboard/projects/new");
  }

  return (
    <AuthShell
      title="Create your account"
      subtitle="3 free video credits, no credit card required."
      footer={
        <>
          Already have an account?{" "}
          <Link href="/sign-in" className="font-medium text-primary hover:underline">
            Sign in
          </Link>
        </>
      }
    >
      <Button variant="outline" className="w-full" onClick={() => router.push("/dashboard/projects/new")}>
        <Mail className="size-4" /> Continue with SSO
      </Button>
      <div className="my-5 flex items-center gap-3">
        <Separator className="flex-1" />
        <span className="text-xs text-muted-foreground">or</span>
        <Separator className="flex-1" />
      </div>
      <form onSubmit={handleSubmit} className="space-y-4">
        <div className="space-y-1.5">
          <Label htmlFor="name">Full name</Label>
          <Input id="name" placeholder="Love Lindberg" required />
        </div>
        <div className="space-y-1.5">
          <Label htmlFor="email">Work email</Label>
          <Input id="email" type="email" placeholder="you@brand.com" defaultValue="love.lindberg10@gmail.com" required />
        </div>
        <div className="space-y-1.5">
          <Label htmlFor="password">Password</Label>
          <Input id="password" type="password" placeholder="••••••••" required />
        </div>
        <Button type="submit" variant="gradient" className="w-full">
          Create account
        </Button>
      </form>
    </AuthShell>
  );
}
