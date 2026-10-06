import type { Metadata } from "next"
import { Playfair_Display } from "next/font/google"
import "./globals.css"

const playfair = Playfair_Display({
  subsets: ["latin"],
  weight: ["400", "700"],
  variable: "--font-playfair",
  display: "swap",
})

export const metadata: Metadata = {
  title: "Munch - Your simple food diary and meal tracker",
  description:
    "Track meals with photos in seconds. A visual food diary app for mindful eating, cooking inspiration, and food memories—without calorie counting. Start your meal journal today.",
  authors: [{ name: "Munch" }],
  keywords: [
    "food diary app",
    "photo food diary",
    "meal journal",
    "visual food diary",
    "meal tracker app",
    "food calendar app",
    "cooking journal",
    "food memories",
    "home cooking",
    "meal inspiration",
    "food timeline",
    "food tracker without calories",
  ],
  creator: "Munch",
  publisher: "Munch",
  robots: "index, follow",
  alternates: {
    canonical: "https://munchdiary.app",
  },
  openGraph: {
    title: "Munch - Your simple food diary and meal tracker",
    description:
      "Track meals with photos in seconds. A visual food diary app for mindful eating and cooking inspiration—without calorie counting.",
    url: "https://munchdiary.app",
    siteName: "Munch",
    locale: "en_US",
    type: "website",
    images: [
      {
        url: "https://munchdiary.app/images/app-icon.png",
        width: 1200,
        height: 630,
        alt: "Munch - Visual Food Diary App for Photo Meal Journaling",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    creator: "@munchdiary",
    title: "Munch - Your simple food diary and meal tracker",
    description:
      "Track meals with photos in seconds. A visual food diary app for mindful eating and cooking inspiration—without calorie counting.",
    images: ["https://munchdiary.app/images/app-icon.png"],
  },
  icons: {
    icon: [
      { url: "/favicon.ico", sizes: "any" },
      { url: "/images/app-icon.png", type: "image/png", sizes: "32x32" },
      { url: "/images/app-icon.png", type: "image/png", sizes: "16x16" },
    ],
    apple: [
      { url: "/images/app-icon.png", type: "image/png", sizes: "180x180" },
    ],
  },
  manifest: "/manifest.json",
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body
        className={`${playfair.variable} font-sans bg-white overflow-x-hidden antialiased`}
      >
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{
            __html: JSON.stringify({
              "@context": "https://schema.org",
              "@type": "SoftwareApplication",
              name: "Munch: Simple Food Diary",
              applicationCategory: "Health & Fitness",
              operatingSystem: "iOS",
              offers: {
                "@type": "Offer",
                price: "0",
                priceCurrency: "USD",
              },
              aggregateRating: {
                "@type": "AggregateRating",
                ratingValue: "4.8",
                ratingCount: "150",
              },
              description:
                "A visual food diary app for tracking meals with photos. Create a meal journal and food timeline without calorie counting.",
              keywords:
                "food diary app, photo food diary, meal journal, visual food diary, meal tracker app",
            }),
          }}
        />
        {children}
      </body>
    </html>
  )
}
