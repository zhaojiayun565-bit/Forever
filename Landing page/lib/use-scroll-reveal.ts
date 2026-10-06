"use client"

import { useEffect } from "react"

const REVEAL_SELECTORS =
  ".hero-section, .feature-section, .faq-section, .scroll-indicator"

/** Adds `.animate-in` when reveal targets enter the viewport. */
export function useScrollReveal() {
  useEffect(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add("animate-in")
          }
        })
      },
      { threshold: 0.1, rootMargin: "0px 0px -40px 0px" }
    )

    const elements = document.querySelectorAll(REVEAL_SELECTORS)
    elements.forEach((el) => {
      observer.observe(el)
      const rect = el.getBoundingClientRect()
      if (rect.top < window.innerHeight * 0.95) {
        el.classList.add("animate-in")
      }
    })

    return () => observer.disconnect()
  }, [])
}
