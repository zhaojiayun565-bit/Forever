"use client"

import Image from "next/image"
import Link from "next/link"
import { MunchCta } from "@/components/munch-cta"

type SiteHeaderProps = {
  onLogoClick?: () => void
}

/** Top navigation with logo, story link, and App Store CTA. */
export function SiteHeader({ onLogoClick }: SiteHeaderProps) {
  const logo = (
    <Image
      src="/images/app-icon.png"
      alt="Munch - Visual food diary app logo"
      width={72}
      height={72}
      className="rounded-lg w-12 h-12 sm:w-14 sm:h-14 md:w-16 md:h-16"
    />
  )

  return (
    <header className="py-4 md:py-6 px-5 sm:px-6 md:px-8" role="banner">
      <div className="max-w-7xl mx-auto flex items-center justify-between">
        <div className="flex-1">
          {onLogoClick ? (
            <button
              type="button"
              onClick={onLogoClick}
              className="cursor-pointer"
              aria-label="Munch logo - return to top of page"
            >
              {logo}
            </button>
          ) : (
            <Link href="/" aria-label="Munch logo - return to home">
              {logo}
            </Link>
          )}
        </div>
        <nav
          className="flex items-center gap-3 sm:gap-4 md:gap-6"
          aria-label="Main navigation"
        >
          <Link
            href="/story"
            className="text-sm sm:text-base md:text-[20px] text-gray-700 hover:text-gray-900"
            aria-label="Read our story"
          >
            Our story
          </Link>
          <MunchCta size="header" ariaLabel="Download Munch food diary app">
            <span className="hidden sm:inline">Get the app</span>
            <span className="sm:hidden">Get app</span>
          </MunchCta>
        </nav>
      </div>
    </header>
  )
}
