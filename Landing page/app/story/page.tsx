import Image from "next/image"
import Link from "next/link"
import { SiteHeader } from "@/components/site-header"
import { SiteFooter } from "@/components/site-footer"

export const metadata = {
  title: "Our Story - Munch",
  description: "Meet the creator behind Munch, a visual food diary app.",
}

export default function StoryPage() {
  return (
    <div className="flex flex-col min-h-screen bg-white overflow-x-hidden">
      <SiteHeader />

      <main className="flex-grow px-5 sm:px-6 md:px-8 py-8 sm:py-12 md:py-16" role="main">
        <div className="max-w-7xl mx-auto">
          <Link
            href="/"
            className="text-xl text-gray-700 hover:text-gray-900 flex items-center gap-2 mb-8 sm:mb-10 md:mb-12"
          >
            <svg
              width="20"
              height="20"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
              aria-hidden
            >
              <path d="M19 12H5M12 19l-7-7 7-7" />
            </svg>
            Back
          </Link>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 sm:gap-10 md:gap-12 items-start">
            <div className="flex justify-center lg:justify-start">
              <Image
                src="/images/casual-pic.jpg"
                alt="Casual picture"
                width={500}
                height={600}
                className="rounded-3xl object-cover w-full max-w-md"
              />
            </div>

            <div className="flex flex-col space-y-4 sm:space-y-6">
              <h1 className="text-[28px] sm:text-[34px] md:text-[46px] font-bold text-gray-900 mb-4 sm:mb-5 md:mb-6 leading-tight">
                Hey, Jia here 👋
              </h1>
              <p className="text-base sm:text-[20px] md:text-[20px] text-gray-600 leading-relaxed">
                I&apos;m a product designer and builder based in Montreal, and I
                created Munch to solve a personal frustration: my cooking
                progress was getting lost in the &quot;deep sea&quot; of my
                phone&apos;s photo gallery. I&apos;ve always preferred cooking
                with intuition and inspiration over following rigid recipe books,
                but I realized that even my saved reels and shorts were being
                forgotten.
              </p>
              <p className="text-base sm:text-[20px] md:text-[20px] text-gray-600 leading-relaxed">
                I wanted a personal &quot;vault&quot;—a curated space for my
                own successful meals so I&apos;d never be at a loss for what to
                cook or what to bring to a potluck. My hope is that Munch makes
                cooking fun and helps you stay accountable to eating healthy
                without the stress of tracking calories or macros.
              </p>
              <p className="text-base sm:text-[20px] md:text-[20px] text-gray-600 leading-relaxed">
                I&apos;d love to hear your feedback or feature requests! Feel
                free to reach out via email at{" "}
                <a
                  href="mailto:jiayun.studio@gmail.com"
                  className="text-[#F67939] hover:underline"
                >
                  jiayun.studio@gmail.com
                </a>{" "}
                or DM me on X (
                <a
                  href="https://x.com/jiayun_studio"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-[#F67939] hover:underline"
                >
                  @jiayun_studio
                </a>
                ).
              </p>
            </div>
          </div>
        </div>
      </main>

      <SiteFooter />
    </div>
  )
}
