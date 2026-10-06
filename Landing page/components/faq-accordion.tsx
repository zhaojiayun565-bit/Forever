"use client"

import { useState } from "react"

const FAQ_ITEMS = [
  {
    id: "who",
    question: "Who is Munch for?",
    answer:
      "Anyone who wants to eat more mindfully, cook better, track food for health reasons, or simply remember the meals they loved.",
  },
  {
    id: "tracker",
    question: "Is this a calorie or macro tracker?",
    answer:
      "No. Munch focuses on awareness and reflection, not restriction or numbers.",
  },
  {
    id: "health",
    question: "Can this help with health tracking?",
    answer:
      "Yes. Many users use it to notice food patterns related to digestion, energy, or blood sugar, without the overwhelm.",
  },
  {
    id: "why",
    question: "Why use Munch instead of notes or photos?",
    answer:
      "Because Munch turns scattered meals into a clear, beautiful food timeline you can actually learn from.",
  },
  {
    id: "storage",
    question: "Will photos take up space on my phone?",
    answer:
      "No — meals are securely saved to the cloud, not your photo library.",
  },
] as const

/** FAQ accordion with one open item at a time. */
export function FaqAccordion() {
  const [openId, setOpenId] = useState<string | null>(null)

  const toggle = (id: string) => {
    setOpenId((current) => (current === id ? null : id))
  }

  return (
    <div className="max-w-3xl mx-auto space-y-0">
      {FAQ_ITEMS.map((item) => {
        const isOpen = openId === item.id
        return (
          <div
            key={item.id}
            className="border-b border-gray-200 last:border-b-0"
          >
            <button
              type="button"
              id={`faq-question-${item.id}`}
              className="w-full flex items-center justify-between py-4 md:py-6 text-left gap-4"
              onClick={() => toggle(item.id)}
              aria-expanded={isOpen}
              aria-controls={`faq-answer-${item.id}`}
            >
              <span className="text-lg md:text-xl font-bold text-gray-900">
                {item.question}
              </span>
              <svg
                className={`w-5 h-5 text-gray-500 flex-shrink-0 transition-transform duration-300 ${
                  isOpen ? "rotate-180" : ""
                }`}
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
                aria-hidden
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M19 9l-7 7-7-7"
                />
              </svg>
            </button>
            <div
              id={`faq-answer-${item.id}`}
              role="region"
              aria-labelledby={`faq-question-${item.id}`}
              className={`faq-answer ${isOpen ? "expanded" : "collapsed"}`}
            >
              <div className="pb-4 md:pb-6 text-gray-600 text-lg md:text-xl leading-relaxed">
                {item.answer}
              </div>
            </div>
          </div>
        )
      })}
    </div>
  )
}
