import type { Metadata } from "next"
import "./globals.css"
import { APP_NAME, SITE_NAME } from "@/lib/constants"

const description =
  "Forever helps couples stay close: a shared memory map, drawings on each other's lock screen, live distance widgets, and daily questions to answer together."

export const metadata: Metadata = {
  title: `${APP_NAME}`,
  description,
  authors: [{ name: SITE_NAME }],
  creator: SITE_NAME,
  publisher: SITE_NAME,
  robots: "index, follow",
  openGraph: {
    title: APP_NAME,
    description,
    siteName: SITE_NAME,
    locale: "en_US",
    type: "website",
  },
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body className="font-sans bg-white text-gray-900 overflow-x-hidden antialiased">
        {children}
      </body>
    </html>
  )
}
