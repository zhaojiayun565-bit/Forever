type LegalDocumentProps = {
  html: string
}

/** Renders legal page body HTML from the live Munch site. */
export function LegalDocument({ html }: LegalDocumentProps) {
  return <div dangerouslySetInnerHTML={{ __html: html }} />
}
