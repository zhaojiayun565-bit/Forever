type LegalProseProps = {
  title: string
  effectiveDate: string
  children: React.ReactNode
}

/** Shared wrapper matching original Munch legal page typography. */
export function LegalProse({ title, effectiveDate, children }: LegalProseProps) {
  return (
    <>
      <h1 className="text-5xl font-bold text-gray-900 mb-8">{title}</h1>
      <div className="prose prose-lg max-w-none text-gray-700 space-y-12">
        <p className="text-sm text-gray-500 mb-8">
          <strong>Effective Date:</strong> {effectiveDate}
        </p>
        {children}
      </div>
    </>
  )
}

type LegalSectionProps = {
  children: React.ReactNode
}

export function LegalSection({ children }: LegalSectionProps) {
  return <section>{children}</section>
}

export function LegalH2({ children }: { children: React.ReactNode }) {
  return (
    <h2 className="text-2xl font-bold text-gray-900 mb-4">{children}</h2>
  )
}

export function LegalH3({ children }: { children: React.ReactNode }) {
  return (
    <h3 className="text-xl font-semibold text-gray-900 mb-3 mt-4">{children}</h3>
  )
}

export function LegalP({
  children,
  className = "",
}: {
  children: React.ReactNode
  className?: string
}) {
  return <p className={className}>{children}</p>
}

export function LegalList({ children }: { children: React.ReactNode }) {
  return <ul className="list-disc pl-6 space-y-2 mt-4">{children}</ul>
}

export function LegalLink({
  href,
  children,
}: {
  href: string
  children: React.ReactNode
}) {
  return (
    <a
      href={href}
      target="_blank"
      rel="noopener noreferrer"
      className="text-[#F67939] hover:underline"
    >
      {children}
    </a>
  )
}

export function LegalEmailLink({ email }: { email: string }) {
  return (
    <a href={`mailto:${email}`} className="text-[#F67939] hover:underline">
      {email}
    </a>
  )
}
