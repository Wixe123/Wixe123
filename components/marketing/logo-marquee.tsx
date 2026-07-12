const BRANDS = [
  "Loop Skincare", "Fetch Supply Co.", "Kindred Coffee", "Agency Nine", "FocusDesk",
  "SnoozeCloud", "IronGrip", "Nomad Roasters", "Bright Bloom", "Ridgeline Gear",
];

export function LogoMarquee() {
  const items = [...BRANDS, ...BRANDS];
  return (
    <section className="border-y border-border/60 bg-secondary/30 py-8">
      <p className="mb-5 text-center text-xs font-medium tracking-wider text-muted-foreground uppercase">
        Trusted by creators and brands shipping ads daily
      </p>
      <div className="relative overflow-hidden">
        <div className="flex w-max animate-marquee gap-12 whitespace-nowrap">
          {items.map((b, i) => (
            <span key={i} className="text-lg font-display font-semibold text-muted-foreground/60">
              {b}
            </span>
          ))}
        </div>
      </div>
    </section>
  );
}
