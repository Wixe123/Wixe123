import Link from "next/link";
import { Logo } from "@/components/layout/logo";
import { Card } from "@/components/ui/card";

export function AuthShell({
  title,
  subtitle,
  children,
  footer,
}: {
  title: string;
  subtitle: string;
  children: React.ReactNode;
  footer: React.ReactNode;
}) {
  return (
    <div className="bg-mesh flex min-h-screen flex-1 flex-col items-center justify-center px-4 py-12">
      <Link href="/" className="mb-8">
        <Logo />
      </Link>
      <Card className="w-full max-w-sm p-7">
        <h1 className="font-display text-xl font-semibold">{title}</h1>
        <p className="mt-1 text-sm text-muted-foreground">{subtitle}</p>
        <div className="mt-6">{children}</div>
        <p className="mt-6 text-center text-sm text-muted-foreground">{footer}</p>
      </Card>
      <p className="mt-6 max-w-sm text-center text-xs text-muted-foreground">
        Demo mode — no real authentication is performed. In production this
        screen is powered by Clerk.
      </p>
    </div>
  );
}
