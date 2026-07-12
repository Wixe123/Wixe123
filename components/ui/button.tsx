import * as React from "react";
import { Slot } from "@radix-ui/react-slot";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils";

const buttonVariants = cva(
  "inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-xl text-sm font-medium transition-all duration-200 disabled:pointer-events-none disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-background cursor-pointer",
  {
    variants: {
      variant: {
        default:
          "bg-primary text-primary-foreground shadow-[0_1px_0_0_rgba(255,255,255,0.15)_inset,0_8px_20px_-8px_var(--primary)] hover:brightness-110 active:brightness-95",
        gradient:
          "text-white bg-[linear-gradient(120deg,var(--gradient-1),var(--gradient-2)_50%,var(--gradient-3))] shadow-[0_8px_24px_-8px_var(--gradient-1)] hover:brightness-110 active:brightness-95 bg-[length:160%_160%] hover:bg-[position:100%_0]",
        destructive:
          "bg-destructive text-destructive-foreground hover:brightness-110",
        outline:
          "border border-border bg-transparent hover:bg-secondary text-foreground",
        secondary: "bg-secondary text-secondary-foreground hover:brightness-95",
        ghost: "hover:bg-secondary text-foreground",
        link: "text-primary underline-offset-4 hover:underline",
        glass: "glass text-foreground hover:brightness-105",
      },
      size: {
        default: "h-10 px-4 py-2 has-[>svg]:px-3.5",
        sm: "h-8 rounded-lg px-3 text-xs has-[>svg]:px-2.5",
        lg: "h-12 rounded-2xl px-7 text-base has-[>svg]:px-6",
        icon: "size-10",
        "icon-sm": "size-8 rounded-lg",
      },
    },
    defaultVariants: {
      variant: "default",
      size: "default",
    },
  }
);

function Button({
  className,
  variant,
  size,
  asChild = false,
  ...props
}: React.ComponentProps<"button"> &
  VariantProps<typeof buttonVariants> & { asChild?: boolean }) {
  const Comp = asChild ? Slot : "button";
  return (
    <Comp
      data-slot="button"
      className={cn(buttonVariants({ variant, size, className }))}
      {...props}
    />
  );
}

export { Button, buttonVariants };
