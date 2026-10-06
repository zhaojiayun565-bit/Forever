/** Same-size stand-in for the hero preview video. */
export function HeroVideoPlaceholder() {
  return (
    <div
      className="flex justify-center items-center mt-6 sm:mt-8 w-full -mx-5 sm:-mx-6 md:-mx-8"
      aria-label="Munch app preview video"
    >
      <div className="w-full sm:max-w-[83.33%] md:max-w-[83.33%] rounded-[20px] sm:rounded-[54px] overflow-hidden shadow-xl sm:shadow-2xl">
        <div className="aspect-video w-full bg-gray-200 flex items-center justify-center">
          <span className="text-gray-400 text-sm sm:text-base font-normal">
            Video placeholder
          </span>
        </div>
      </div>
    </div>
  )
}
