"use client";

import * as React from "react";
import * as SliderPrimitive from "@radix-ui/react-slider";
import { cn } from "@/lib/utils";

function Slider({
  className,
  defaultValue,
  value,
  ...props
}: React.ComponentProps<typeof SliderPrimitive.Root>) {
  const values = React.useMemo(
    () => (Array.isArray(value) ? value : Array.isArray(defaultValue) ? defaultValue : [0]),
    [value, defaultValue]
  );
  return (
    <SliderPrimitive.Root
      data-slot="slider"
      defaultValue={defaultValue}
      value={value}
      className={cn(
        "relative flex w-full touch-none items-center select-none data-[disabled]:opacity-50",
        className
      )}
      {...props}
    >
      <SliderPrimitive.Track className="relative h-1.5 w-full grow overflow-hidden rounded-full bg-secondary">
        <SliderPrimitive.Range className="absolute h-full bg-[linear-gradient(120deg,var(--gradient-1),var(--gradient-2))]" />
      </SliderPrimitive.Track>
      {values.map((_, i) => (
        <SliderPrimitive.Thumb
          key={i}
          className="block size-4 rounded-full border-2 border-primary bg-background shadow transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring disabled:pointer-events-none disabled:opacity-50"
        />
      ))}
    </SliderPrimitive.Root>
  );
}

export { Slider };
