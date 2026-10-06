import { SUPPORT_EMAIL } from "@/lib/support-email"
import {
  LegalEmailLink,
  LegalH2,
  LegalList,
  LegalP,
  LegalProse,
  LegalSection,
} from "@/components/legal/legal-prose"

export function PrivacyContent() {
  return (
    <LegalProse title="Privacy Policy" effectiveDate="June 3, 2026">
      <LegalSection>
        <LegalH2>1. Privacy Philosophy & Governance</LegalH2>
        <LegalP>
          {`"Forever: App for Couples" is built to protect the intimate data shared between partners. We do not sell your personal data to advertisers, and we minimize data collection to only what is technically required to run a real-time, paired application.`}
        </LegalP>
        <LegalP className="mt-4">
          <strong>Privacy Officer:</strong> Under local data protection acts
          (including Quebec Law 25), the person responsible for data protection is
          the App Founder. You can reach them at the contact email below.
        </LegalP>
      </LegalSection>

      <LegalSection>
        <LegalH2>2. Information We Collect & Processing Purpose</LegalH2>
        <LegalP>
          To link two devices together and sync drawings, maps, and widgets
          instantly, we collect and process the following:
        </LegalP>
        <LegalList>
          <li>
            <strong>Anonymous Account Identifiers:</strong> We use anonymous
            authentication tokens to safely route data packages to you and your
            partner. We do not require your real name or phone number to set up an
            account.
          </li>
          <li>
            <strong>User-Generated Shared Content:</strong> Drawings, canvas paths,
            map coordinates for shared memories, and widget assets. This data is
            stored in secure, private cloud tables dedicated to your paired
            session.
          </li>
          <li>
            <strong>Real-time Connection State:</strong> Temporary indicators
            required to let the cloud infrastructure know if you or your partner
            are online to receive live updates.
          </li>
          <li>
            <strong>App Diagnostics & Performance Analytics:</strong> We track
            anonymous performance logs and crash metadata to debug user interface
            hitches, network synchronization failures, and UI animation lag.
          </li>
        </LegalList>
      </LegalSection>

      <LegalSection>
        <LegalH2>3. Data Storage & Cross-Border Transfers</LegalH2>
        <LegalP>
          Our cloud backend infrastructure is powered by Supabase and Google
          Firebase. While your data is protected by strict row-level security
          constraints (ensuring only you and your paired partner can access your
          data rows), please note that data may be transferred to and processed in
          secure cloud data centers located outside of your resident territory or
          country (including the United States). By using the App, you consent to
          this cross-border transfer necessary to execute the real-time application
          sync.
        </LegalP>
      </LegalSection>

      <LegalSection>
        <LegalH2>4. Privacy by Default & Your Rights</LegalH2>
        <LegalP>
          {`In accordance with modern privacy frameworks (such as Quebec Law 25, Europe's GDPR, and California's CCPA/CPRA), you have the following rights:`}
        </LegalP>
        <LegalList>
          <li>
            <strong>Privacy by Default:</strong> We do not track your device for
            cross-app behavioral advertising purposes. Any non-essential analytical
            tracking is disabled by default.
          </li>
          <li>
            <strong>Right to Access & Portability:</strong> You can request a copy
            of your stored database records at any time.
          </li>
          <li>
            <strong>Right to Deletion:</strong> When you choose to permanently wipe
            your data, or if you unpair and submit a deletion request, we will
            expunge your shared data records from our active cloud databases.
          </li>
          <li>
            <strong>Minors:</strong>{" "}
            {`"Forever: App for Couples" is strictly rated for users aged 16 and older. We do not knowingly collect, process, or store personal information from individuals under 16 years of age. If we discover that an account has been created by anyone under 16, we will immediately expunge all associated data from our cloud infrastructure.`}
          </li>
        </LegalList>
      </LegalSection>

      <LegalSection>
        <LegalH2>5. Third-Party Service Providers</LegalH2>
        <LegalP>
          We partner with a minimal number of trusted infrastructure and service
          providers to securely run the App:
        </LegalP>
        <LegalList>
          <li>
            <strong>Supabase:</strong> Real-time web socket data routing and secure
            database storage.
          </li>
          <li>
            <strong>Google Firebase:</strong> App configuration, performance
            diagnostics, crash logging, and cloud infrastructure synchronization.
          </li>
          <li>
            <strong>RevenueCat:</strong> Subscription state validation, transaction
            verification, and entitlement tracking.
          </li>
          <li>
            <strong>Apple App Store:</strong> Identity token validation, transaction
            management, and secure payment processing.
          </li>
        </LegalList>
      </LegalSection>

      <LegalSection>
        <LegalH2>6. Data Retention</LegalH2>
        <LegalP>
          We retain your shared data only for as long as your account remains active
          and paired. If you completely delete the app or remain inactive for an
          extended period, we reserve the right to scrub old, unlinked real-time
          drawing caches to optimize server overhead.
        </LegalP>
      </LegalSection>

      <LegalSection>
        <LegalH2>7. Contact</LegalH2>
        <LegalP>
          For any data privacy inquiries or to exercise your rights, contact our
          Privacy Officer at:
        </LegalP>
        <LegalP className="mt-4">
          Email: <LegalEmailLink email={SUPPORT_EMAIL} />
        </LegalP>
      </LegalSection>
    </LegalProse>
  )
}
