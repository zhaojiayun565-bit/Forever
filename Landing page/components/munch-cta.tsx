import Link from "next/link"
import { cn } from "@/lib/utils"
import { APP_STORE_URL } from "@/lib/constants"
import { ArrowIcon } from "@/components/arrow-icon"

type MunchCtaProps = {
  children: React.ReactNode
  className?: string
  ariaLabel: string
  size?: "header" | "hero"
}

const sizeClasses = {
  header:
    "px-4 sm:px-6 md:px-8 py-3 md:py-4 text-[14px] sm:text-[16px] md:text-[20px] h-12 md:h-14",
  hero: "px-6 sm:px-8 md:px-10 py-3 sm:py-4 text-[14px] sm:text-[16px] md:text-[20px] h-12 sm:h-14",
}

/** Orange pill CTA linking to the App Store. */
export function MunchCta({
  children,
  className,
  ariaLabel,
  size = "hero",
}: MunchCtaProps) {
  return (
    <Link
      href={APP_STORE_URL}
      className={cn(
        "inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-full font-bold text-white shadow bg-[#F67939] hover:bg-[#F67939]/90 transition-colors focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring group",
        sizeClasses[size],
        className
      )}
      aria-label={ariaLabel}
    >
      {children}
      <ArrowIcon />
    </Link>
  )
}
