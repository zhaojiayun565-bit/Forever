import Link from "next/link"
import { SITE_NAME } from "@/lib/constants"
import { SUPPORT_EMAIL } from "@/lib/support-email"

/** Footer with copyright, legal links, and support contact. */
export function SiteFooter() {
  return (
    <footer className="border-t border-gray-100 py-8 px-5 sm:px-6 md:px-8" role="contentinfo">
      <div className="max-w-5xl mx-auto flex flex-col sm:flex-row gap-4 sm:items-center sm:justify-between text-sm text-gray-500">
        <p>
          {SITE_NAME} © {new Date().getFullYear()}
        </p>
        <nav className="flex flex-wrap gap-5" aria-label="Footer navigation">
          <Link href="/privacy" className="hover:text-gray-900">
            Privacy Policy
          </Link>
          <Link href="/terms" className="hover:text-gray-900">
            Terms of Service
          </Link>
          <a href={`mailto:${SUPPORT_EMAIL}`} className="hover:text-gray-900">
            {SUPPORT_EMAIL}
          </a>
        </nav>
      </div>
    </footer>
  )
}
