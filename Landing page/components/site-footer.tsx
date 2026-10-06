"use client"

import Image from "next/image"
import Link from "next/link"
import { APP_STORE_URL } from "@/lib/constants"

type SiteFooterProps = {
  onLogoClick?: () => void
}

/** Site footer with logo, links, and copyright. */
export function SiteFooter({ onLogoClick }: SiteFooterProps) {
  const logo = (
    <Image
      src="/images/app-icon.png"
      alt="Munch - Visual food diary app logo"
      width={64}
      height={64}
      className="rounded-lg w-12 h-12 sm:w-14 sm:h-14 md:w-16 md:h-16"
    />
  )

  return (
    <footer
      className="bg-white py-8 sm:py-10 md:py-12 px-5 sm:px-6 md:px-8"
      role="contentinfo"
    >
      <div className="max-w-7xl mx-auto">
        <div className="border-t border-gray-200 pt-8 sm:pt-10 md:pt-12">
          <div className="flex flex-col md:grid md:grid-cols-4 gap-6 sm:gap-8">
            <div className="flex flex-col md:col-span-1">
              {onLogoClick ? (
                <button
                  type="button"
                  onClick={onLogoClick}
                  className="cursor-pointer w-fit mb-3 sm:mb-4"
                  aria-label="Munch logo - return to top"
                >
                  {logo}
                </button>
              ) : (
                <Link
                  href="/"
                  className="w-fit mb-3 sm:mb-4"
                  aria-label="Munch logo - return to home"
                >
                  {logo}
                </Link>
              )}
              <p className="text-base sm:text-lg text-gray-400 hidden md:block">
                Munch © 2026
              </p>
            </div>

            <div className="flex flex-row md:contents gap-6 sm:gap-8 md:gap-0">
              <div className="flex flex-col flex-1 md:col-span-1">
                <h3 className="text-base sm:text-lg font-medium text-gray-500 mb-3 sm:mb-4">
                  Munch
                </h3>
                <div className="flex flex-col space-y-2 sm:space-y-3">
                  <a
                    href={APP_STORE_URL}
                    className="text-base sm:text-lg text-gray-400 hover:text-gray-600 transition-colors"
                  >
                    Download App
                  </a>
                  <Link
                    href="/story"
                    className="text-base sm:text-lg text-gray-400 hover:text-gray-600 transition-colors"
                  >
                    Our Story
                  </Link>
                  <a
                    href="mailto:hello@munchdiary.app"
                    className="text-base sm:text-lg text-gray-400 hover:text-gray-600 transition-colors"
                  >
                    Contact Us
                  </a>
                </div>
              </div>

              <div className="flex flex-col flex-1 md:col-span-1">
                <h3 className="text-base sm:text-lg font-medium text-gray-500 mb-3 sm:mb-4">
                  Company
                </h3>
                <div className="flex flex-col space-y-2 sm:space-y-3">
                  <Link
                    href="/terms"
                    className="text-base sm:text-lg text-gray-400 hover:text-gray-600 transition-colors"
                  >
                    Terms of Service
                  </Link>
                  <Link
                    href="/privacy"
                    className="text-base sm:text-lg text-gray-400 hover:text-gray-600 transition-colors"
                  >
                    Privacy Policy
                  </Link>
                </div>
              </div>

              <div className="flex flex-col flex-1 md:col-span-1">
                <h3 className="text-base sm:text-lg font-medium text-gray-500 mb-3 sm:mb-4">
                  Social
                </h3>
                <div className="flex flex-col space-y-2 sm:space-y-3">
                  <a
                    href="#tiktok"
                    className="text-base sm:text-lg text-gray-400 hover:text-gray-600 transition-colors"
                  >
                    TikTok
                  </a>
                  <a
                    href="#instagram"
                    className="text-base sm:text-lg text-gray-400 hover:text-gray-600 transition-colors"
                  >
                    Instagram
                  </a>
                </div>
              </div>
            </div>
          </div>

          <div className="mt-6 md:hidden">
            <p className="text-base sm:text-lg text-gray-400">Munch © 2026</p>
          </div>
        </div>
      </div>
    </footer>
  )
}
