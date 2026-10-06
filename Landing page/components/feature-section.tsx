import Image from "next/image"

type FeatureSectionProps = {
  id: string
  title: string
  description: string
  imageSrc: string
  imageAlt: string
  imageOnLeft?: boolean
}

/** Alternating two-column feature block with scroll animations. */
export function FeatureSection({
  id,
  title,
  description,
  imageSrc,
  imageAlt,
  imageOnLeft = false,
}: FeatureSectionProps) {
  const textOrder = imageOnLeft ? "order-1 lg:order-2" : ""
  const imageOrder = imageOnLeft ? "order-2 lg:order-1" : ""
  const textSlide = imageOnLeft ? "slide-in-right" : "slide-in-left"
  const imageSlide = imageOnLeft ? "slide-in-left" : "slide-in-right"

  return (
    <section
      className="py-12 sm:py-16 md:py-20 px-5 sm:px-6 md:px-8 bg-white feature-section"
      aria-labelledby={id}
    >
      <div className="max-w-7xl mx-auto">
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 sm:gap-10 md:gap-12 items-center">
          <div
            className={`flex flex-col ${textSlide} opacity-0 text-left max-w-2xl lg:max-w-none mx-0 ${textOrder}`}
          >
            <h2
              id={id}
              className="text-[28px] sm:text-[34px] md:text-[46px] font-bold text-gray-900 mb-4 sm:mb-5 md:mb-6 leading-tight"
            >
              {title}
            </h2>
            <p className="text-base sm:text-[20px] md:text-[20px] text-gray-600 leading-relaxed">
              {description}
            </p>
          </div>
          <div
            className={`flex justify-center items-center ${imageSlide} opacity-0 ${imageOrder}`}
          >
            <div className="w-full max-w-[291px] sm:max-w-[349px]">
              <Image
                src={imageSrc}
                alt={imageAlt}
                width={400}
                height={711}
                className="w-full h-auto rounded-2xl"
                priority={imageSrc === "/images/feature-1.png"}
              />
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}
