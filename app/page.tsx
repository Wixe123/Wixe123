import { Navbar } from "@/components/marketing/navbar";
import { Hero } from "@/components/marketing/hero";
import { LogoMarquee } from "@/components/marketing/logo-marquee";
import { FeaturesGrid } from "@/components/marketing/features-grid";
import { WorkflowSteps } from "@/components/marketing/workflow-steps";
import { ComparisonTable } from "@/components/marketing/comparison-table";
import { Testimonials } from "@/components/marketing/testimonials";
import { PricingSection } from "@/components/marketing/pricing-section";
import { FAQ } from "@/components/marketing/faq";
import { CtaBand } from "@/components/marketing/cta-band";
import { Footer } from "@/components/marketing/footer";

export default function Home() {
  return (
    <div className="flex flex-1 flex-col">
      <Navbar />
      <Hero />
      <LogoMarquee />
      <FeaturesGrid />
      <WorkflowSteps />
      <ComparisonTable />
      <Testimonials />
      <PricingSection />
      <FAQ />
      <CtaBand />
      <Footer />
    </div>
  );
}
