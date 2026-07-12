import Link from "next/link";
import { cn } from "@/lib/utils";

export function Logo({ className, href = "/" }: { className?: string; href?: string }) {
  return (
    <Link href={href} className={cn("flex items-center gap-2 font-display font-bold", className)}>
      <span className="flex size-8 items-center justify-center rounded-lg bg-[linear-gradient(135deg,var(--gradient-1),var(--gradient-2))] text-white shadow-[0_4px_14px_-4px_var(--gradient-1)]">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <path
            d="M12 2L14.5 9.5L22 12L14.5 14.5L12 22L9.5 14.5L2 12L9.5 9.5L12 2Z"
            fill="currentColor"
          />
        </svg>
      </span>
      <span className="text-[15px] tracking-tight">
        CreatorAI <span className="text-muted-foreground font-medium">UGC Studio</span>
      </span>
    </Link>
  );
}
