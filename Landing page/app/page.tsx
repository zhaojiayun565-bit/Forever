import { SiteHeader } from "@/components/site-header"
import { SiteFooter } from "@/components/site-footer"
import { APP_STORE_URL, BRAND_PINK } from "@/lib/constants"
import { SUPPORT_EMAIL } from "@/lib/support-email"

const features = [
  {
    title: "Memory Map",
    body: "Pin the photos and moments you share to a map you build together.",
  },
  {
    title: "Drawing Board",
    body: "Doodle a note and it shows up on your partner's Home and Lock Screen.",
  },
  {
    title: "Distance Widget",
    body: "See how far apart you are, updated whenever either of you opens the app.",
  },
  {
    title: "Daily Questions",
    body: "Answer a question each day and unlock each other's answers.",
  },
]

const faqs = [
  {
    question: "How do I pair with my partner?",
    answer: "Open the app, share your invite code with your partner, and have them enter it during setup.",
  },
  {
    question: "How do I manage or cancel my subscription?",
    answer: "Subscriptions are handled by Apple. Open Settings on your iPhone, tap your name, then Subscriptions.",
  },
  {
    question: "How do I delete my account?",
    answer:
      "In the app, go to the Me tab and tap Delete Account. This permanently deletes your profile, photos, memories, and drawings, and unpairs you from your partner.",
  },
]

export default function Home() {
  return (
    <div className="flex flex-col min-h-screen">
      <SiteHeader />

      <main className="flex-grow px-5 sm:px-6 md:px-8" role="main">
        <section className="max-w-5xl mx-auto py-16 md:py-24">
          <h1 className="text-5xl md:text-7xl font-semibold tracking-tight leading-tight">
            Stay close,
            <br />
            <span style={{ color: BRAND_PINK }}>wherever you are.</span>
          </h1>
          <p className="mt-6 text-lg md:text-xl text-gray-600 max-w-2xl">
            Forever is a private space for the two of you: your memories, your drawings, and the little things that
            keep you connected every day.
          </p>
          <p className="mt-8 text-base text-gray-500">
            {APP_STORE_URL ? (
              <a href={APP_STORE_URL} className="font-medium" style={{ color: BRAND_PINK }}>
                Download on the App Store
              </a>
            ) : (
              "Coming soon to the App Store."
            )}
          </p>
        </section>

        <section className="max-w-5xl mx-auto pb-16 md:pb-24 grid gap-6 sm:grid-cols-2" aria-label="Features">
          {features.map((feature) => (
            <div key={feature.title} className="rounded-3xl bg-gray-50 p-7">
              <h2 className="text-xl font-semibold">{feature.title}</h2>
              <p className="mt-2 text-gray-600">{feature.body}</p>
            </div>
          ))}
        </section>

        <section id="support" className="max-w-5xl mx-auto pb-20 md:pb-28 scroll-mt-8">
          <h2 className="text-3xl md:text-4xl font-semibold tracking-tight">Support</h2>
          <p className="mt-4 text-gray-600">
            Questions, feedback, or something not working? Email us at{" "}
            <a href={`mailto:${SUPPORT_EMAIL}`} className="font-medium" style={{ color: BRAND_PINK }}>
              {SUPPORT_EMAIL}
            </a>{" "}
            and we&apos;ll get back to you.
          </p>
          <dl className="mt-10 space-y-8">
            {faqs.map((faq) => (
              <div key={faq.question}>
                <dt className="text-lg font-semibold">{faq.question}</dt>
                <dd className="mt-2 text-gray-600">{faq.answer}</dd>
              </div>
            ))}
          </dl>
        </section>
      </main>

      <SiteFooter />
    </div>
  )
}
