import Link from "next/link"
import { BRAND_PINK, SITE_NAME } from "@/lib/constants"

const navLinks = [
  { href: "/privacy", label: "Privacy" },
  { href: "/terms", label: "Terms" },
  { href: "/#support", label: "Support" },
]

/** Top navigation with the Forever wordmark and legal/support links. */
export function SiteHeader() {
  return (
    <header className="py-5 md:py-7 px-5 sm:px-6 md:px-8" role="banner">
      <div className="max-w-5xl mx-auto flex items-center justify-between">
        <Link href="/" aria-label={`${SITE_NAME} home`} className="text-2xl md:text-3xl font-semibold tracking-tight">
          {SITE_NAME}
          <span style={{ color: BRAND_PINK }}>.</span>
        </Link>
        <nav className="flex items-center gap-4 sm:gap-6" aria-label="Main navigation">
          {navLinks.map((link) => (
            <Link key={link.href} href={link.href} className="text-sm sm:text-base text-gray-600 hover:text-gray-900">
              {link.label}
            </Link>
          ))}
        </nav>
      </div>
    </header>
  )
}
