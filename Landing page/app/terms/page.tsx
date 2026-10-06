import { SiteHeader } from "@/components/site-header"
import { SiteFooter } from "@/components/site-footer"
import { TermsContent } from "@/components/legal/terms-content"

export const metadata = {
  title: "Terms of Service - Forever",
  description: "Terms of Service for Forever: App for Couples.",
}

export default function TermsPage() {
  return (
    <div className="flex flex-col min-h-screen bg-white overflow-x-hidden">
      <SiteHeader />

      <main
        className="flex-grow px-5 sm:px-6 md:px-8 py-8 sm:py-12 md:py-16"
        role="main"
      >
        <div className="max-w-4xl mx-auto">
          <TermsContent />
        </div>
      </main>

      <SiteFooter />
    </div>
  )
}
