import { SiteHeader } from "@/components/site-header"
import { SiteFooter } from "@/components/site-footer"
import { PrivacyContent } from "@/components/legal/privacy-content"

export const metadata = {
  title: "Privacy Policy - Forever",
  description: "Privacy Policy for Forever: App for Couples.",
}

export default function PrivacyPage() {
  return (
    <div className="flex flex-col min-h-screen bg-white overflow-x-hidden">
      <SiteHeader />

      <main
        className="flex-grow px-5 sm:px-6 md:px-8 py-8 sm:py-12 md:py-16"
        role="main"
      >
        <div className="max-w-4xl mx-auto">
          <PrivacyContent />
        </div>
      </main>

      <SiteFooter />
    </div>
  )
}
