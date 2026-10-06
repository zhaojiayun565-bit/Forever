"use client"

import { SiteHeader } from "@/components/site-header"
import { SiteFooter } from "@/components/site-footer"
import { MunchCta } from "@/components/munch-cta"
import { HeroVideoPlaceholder } from "@/components/hero-video-placeholder"
import { FeatureSection } from "@/components/feature-section"
import { FaqAccordion } from "@/components/faq-accordion"
import { useScrollReveal } from "@/lib/use-scroll-reveal"

export default function Page() {
  useScrollReveal()

  const scrollToTop = () => {
    window.scrollTo({ top: 0, behavior: "smooth" })
  }

  return (
    <div className="flex flex-col min-h-screen bg-white overflow-x-hidden">
      <SiteHeader onLogoClick={scrollToTop} />

      <main className="flex-grow" role="main">
        <section
          className="hero-section py-8 sm:py-12 md:py-16 px-5 sm:px-6 md:px-8"
          aria-labelledby="hero-heading"
        >
          <div className="max-w-7xl mx-auto">
            <div className="flex flex-col items-center text-center space-y-4 sm:space-y-6 md:space-y-6">
              <h1
                id="hero-heading"
                className="text-[28px] sm:text-[34px] md:text-[46px] font-bold text-gray-900 leading-tight px-4"
              >
                Turn meals into memories
              </h1>
              <p className="text-base sm:text-[20px] md:text-[20px] text-gray-600 leading-relaxed max-w-2xl px-4">
                A visual food diary for your cooking journey.
              </p>
              <div className="pt-2">
                <MunchCta
                  ariaLabel="Start logging meals with Munch food diary app"
                >
                  Start logging meals
                </MunchCta>
              </div>
              <HeroVideoPlaceholder />
            </div>
          </div>
        </section>

        <div
          className="scroll-indicator flex items-center justify-center gap-2 py-6 sm:hidden"
          aria-hidden="true"
        >
          <span className="text-gray-500 text-sm">Scroll</span>
          <svg
            className="w-4 h-4 text-gray-500"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
            aria-hidden
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M19 14l-7 7m0 0l-7-7m7 7V3"
            />
          </svg>
        </div>

        <FeatureSection
          id="log-meals-heading"
          title="Log meals in seconds"
          description="Save meals with a photo and a note. No calories, no pressure. Just an easy way to track what you actually eat."
          imageSrc="/images/feature-1.png"
          imageAlt="Munch app - Log meals feature"
        />

        <FeatureSection
          id="patterns-heading"
          title="See patterns over time"
          description="View your food by calendar and timeline to spot habits, preferences, and what truly makes you feel good."
          imageSrc="/images/feature-2.png"
          imageAlt="Munch app - See patterns over time feature"
          imageOnLeft
        />

        <FeatureSection
          id="food-journey-heading"
          title="Relive your food journey"
          description="Like Spotify Wrapped for food. Look back on your favorite meals and the memories attached to them."
          imageSrc="/images/feature-3.png"
          imageAlt="Munch app - Relive your food journey feature"
        />

        <section
          className="faq-section py-12 sm:py-16 md:py-20 px-5 sm:px-6 md:px-8 bg-white"
          aria-labelledby="faq-heading"
        >
          <div className="max-w-7xl mx-auto">
            <h2
              id="faq-heading"
              className="text-[28px] sm:text-[34px] md:text-[46px] font-bold text-gray-900 text-center mb-8 sm:mb-10 md:mb-12"
            >
              FAQ
            </h2>
            <FaqAccordion />
          </div>
        </section>
      </main>

      <SiteFooter onLogoClick={scrollToTop} />
    </div>
  )
}
