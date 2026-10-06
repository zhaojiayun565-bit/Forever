import { SUPPORT_EMAIL } from "@/lib/support-email"
import {
  LegalEmailLink,
  LegalH2,
  LegalH3,
  LegalLink,
  LegalList,
  LegalP,
  LegalProse,
  LegalSection,
} from "@/components/legal/legal-prose"

const EULA_URL =
  "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"

export function TermsContent() {
  return (
    <LegalProse title="Terms of Service" effectiveDate="June 3, 2026">
      <LegalSection>
        <LegalH2>1. Agreement to Terms</LegalH2>
        <LegalH3>1.1 Standard EULA Applies</LegalH3>
        <LegalP>
          {`The "Forever: App for Couples" mobile application (the "App") is licensed to you under the standard Apple Licensed Application End User License Agreement (Standard EULA). By using the App, you agree to be bound by the Standard EULA (`}
          <LegalLink href={EULA_URL}>{EULA_URL}</LegalLink>
          ).
        </LegalP>
        <LegalH3>1.2 Supplemental Terms</LegalH3>
        <LegalP>
          {`These Terms of Service ("Terms") supplement the Standard EULA. If there is a conflict, the Standard EULA controls regarding the application license, and these Terms shall control regarding specific App features (subscriptions, user pairing, real-time synchronization, and liability).`}
        </LegalP>
        <LegalH3>1.3 Age Requirement</LegalH3>
        <LegalP>
          {`You must be at least 16 years of age to download, access, or use "Forever: App for Couples". By using the App, you represent and warrant that you are at least 16 years old and meet the minimum legal age of digital consent in your jurisdiction. If you are under 16, you are strictly prohibited from using the App.`}
        </LegalP>
      </LegalSection>

      <LegalSection>
        <LegalH2>2. Description of Service & Real-Time Synchronization</LegalH2>
        <LegalP>
          {`"Forever: App for Couples" is a shared digital space for couples featuring real-time drawing boards, shared widgets, and memory mapping.`}
        </LegalP>
        <LegalH3>2.1 User Pairing & Connectivity</LegalH3>
        <LegalP>
          {`The App relies on a multi-user pairing architecture. To use the shared features, you must link your account with your partner's account using a unique pairing code. Real-time features require an active internet connection to synchronize data via our cloud infrastructure.`}
        </LegalP>
        <LegalH3>2.2 Unpairing & Local State Deletion</LegalH3>
        <LegalP>
          You or your partner may choose to unpair your devices at any time.
          Unpairing is a destructive action regarding your shared space. Upon
          unpairing:
        </LegalP>
        <LegalList>
          <li>Your local device state will clear its connection parameters.</li>
          <li>
            Shared active states (like live drawing boards) will disconnect.
          </li>
          <li>
            You are responsible for executing the unpair function within the app
            settings to clean up local cache. We are not liable for residual data
            appearing if an unpair action fails due to local network errors,
            device cold-starts, or unexpected client crashes.
          </li>
        </LegalList>
      </LegalSection>

      <LegalSection>
        <LegalH2>3. Subscriptions & Purchases</LegalH2>
        <LegalP>
          The App offers premium feature upgrades via auto-renewing subscriptions
          billed on a weekly or annual basis.
        </LegalP>
        <LegalP className="mt-4">
          <strong>Payment:</strong> Charged to your Apple ID at confirmation of
          purchase. Prices vary by region and are managed through Apple App Store
          localization.
        </LegalP>
        <LegalP className="mt-4">
          <strong>Auto-Renewal:</strong> Subscriptions renew automatically unless
          canceled at least 24 hours before the end of the current billing cycle.
        </LegalP>
        <LegalP className="mt-4">
          <strong>Management & Cancellations:</strong> All transactions,
          renewals, and cancellations are handled exclusively by Apple. We cannot
          issue refunds or manage your subscription billing status directly.
        </LegalP>
      </LegalSection>

      <LegalSection>
        <LegalH2>4. Intellectual Property & User Content</LegalH2>
        <LegalP>
          {`You and your partner retain full ownership of the text, drawings, and photos ("User Content") you create within the App. By using the shared features, you grant us a narrow, technical, non-exclusive license to host, store, and transmit your User Content solely to facilitate the real-time syncing of data between your device and your partner's device.`}
        </LegalP>
        <LegalP className="mt-4">
          {`All rights, title, and interest in the App's code, UI design, animations, layouts, and branding belong exclusively to the developer.`}
        </LegalP>
      </LegalSection>

      <LegalSection>
        <LegalH2>5. Limitation of Liability</LegalH2>
        <LegalP>
          {`To the maximum extent permitted by law, "Forever: App for Couples" is provided "AS IS". We do not guarantee uninterrupted, real-time connectivity. We are not liable for:`}
        </LegalP>
        <LegalList>
          <li>
            Data synchronization failures, server downtime, or loss of
            drawings/memories.
          </li>
          <li>
            Any relationship disruptions, emotional distress, or real-world
            consequences resulting from your use of the App, data delivery
            failures, or the unpairing of accounts.
          </li>
          <li>
            Network data charges incurred from real-time asset streaming.
          </li>
        </LegalList>
      </LegalSection>

      <LegalSection>
        <LegalH2>6. Governing Law & Dispute Resolution</LegalH2>
        <LegalP>
          These Terms shall be governed by and construed in accordance with the
          laws of the Province of Quebec, Canada, without regard to conflict of law
          principles. Any legal action or proceeding arising under these Terms
          will be brought exclusively in the courts located in Montreal, Quebec,
          Canada.
        </LegalP>
        <LegalP className="mt-4">
          <strong>For users residing in the United States:</strong> You agree that
          any dispute arising out of or relating to this App shall be resolved
          through binding, individual arbitration, and you waive your right to
          participate in a class-action lawsuit or class-wide arbitration.
        </LegalP>
      </LegalSection>

      <LegalSection>
        <LegalH2>7. Contact</LegalH2>
        <LegalP>
          Support Email: <LegalEmailLink email={SUPPORT_EMAIL} />
        </LegalP>
      </LegalSection>
    </LegalProse>
  )
}
