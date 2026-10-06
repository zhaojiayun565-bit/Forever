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
    <LegalProse title="Privacy Policy" effectiveDate="October 6, 2026">
      <LegalSection>
        <LegalH2>1. Overview</LegalH2>
        <LegalP>
          {`"Forever: App for Couples" ("Forever", "we", "us") is a private app for two partners. This policy explains what we collect, why, who it is shared with, and the choices you have. We do not sell your personal information, show ads, or track you across other companies' apps and websites.`}
        </LegalP>
        <LegalP className="mt-4">
          <strong>Person responsible for privacy:</strong> the app&apos;s founder, reachable at the email in the Contact
          section below (including for the purposes of Quebec Law 25).
        </LegalP>
      </LegalSection>

      <LegalSection>
        <LegalH2>2. Information We Collect</LegalH2>
        <LegalList>
          <li>
            <strong>Account information:</strong> when you use Sign in with Apple, we receive a unique account
            identifier and, if you choose to share them, your name and email address (which may be an Apple private
            relay address).
          </li>
          <li>
            <strong>Profile details you enter:</strong> your display name, a nickname for your partner, your
            anniversary date, an optional profile photo, and your pairing code.
          </li>
          <li>
            <strong>Content you create:</strong> memories (photos, notes, dates, and the place you pin them to),
            drawings and drawing-board wallpapers, love messages, saved messages and screenshots in Cherished Texts,
            and your answers to daily questions.
          </li>
          <li>
            <strong>Location (with your permission):</strong> while you use the app, we read your device location to
            calculate the distance between you and your partner for the in-app experience and widgets. We store only
            your most recent location, which is replaced each time it updates. You can turn this off at any time in
            iOS Settings.
          </li>
          <li>
            <strong>Photo metadata:</strong> when you add a photo to a memory, we read the date and location saved in
            that photo to pre-fill the memory. We only access photos you select or allow.
          </li>
          <li>
            <strong>Device information:</strong> your device&apos;s battery level (shown to your partner on widgets),
            time zone (to send reminders at a sensible local time), and a push notification token (to deliver
            notifications to your device).
          </li>
          <li>
            <strong>Purchase information:</strong> your subscription status and transaction history from Apple, via
            RevenueCat. We never receive your payment card details.
          </li>
        </LegalList>
        <LegalP className="mt-4">
          We do not use third-party analytics, advertising, or tracking SDKs. If you opt in to sharing diagnostics
          with Apple, Apple may provide us with anonymous crash reports.
        </LegalP>
      </LegalSection>

      <LegalSection>
        <LegalH2>3. How We Use Your Information</LegalH2>
        <LegalList>
          <li>To create your account and pair you with your partner.</li>
          <li>To sync memories, drawings, messages, and answers between you and your partner in real time.</li>
          <li>To power Home Screen and Lock Screen widgets, including the distance widget.</li>
          <li>To send notifications you can control, such as new drawings or daily question reminders.</li>
          <li>To verify your subscription and unlock premium features for you and your partner.</li>
          <li>To provide support, keep the service secure, and fix problems.</li>
        </LegalList>
      </LegalSection>

      <LegalSection>
        <LegalH2>4. Who Can See Your Information</LegalH2>
        <LegalP>
          <strong>Your partner:</strong> once you pair, your partner can see the content you share in the app, your
          profile details, your distance and approximate location as used by the distance features, and your battery
          level. No one else using Forever can see your data.
        </LegalP>
        <LegalP className="mt-4">
          <strong>Service providers</strong> that process data on our behalf, only to run the app:
        </LegalP>
        <LegalList>
          <li>
            <strong>Supabase:</strong> account authentication, database, file storage, and server functions.
          </li>
          <li>
            <strong>RevenueCat:</strong> subscription and purchase validation.
          </li>
          <li>
            <strong>Apple:</strong> Sign in with Apple, push notification delivery, and App Store payments.
          </li>
        </LegalList>
        <LegalP className="mt-4">
          We may also disclose information if required by law. We do not sell or rent your personal information.
        </LegalP>
      </LegalSection>

      <LegalSection>
        <LegalH2>5. Storage, Security & International Transfers</LegalH2>
        <LegalP>
          Your data is encrypted in transit and protected by access rules that limit it to you and your paired partner.
          Our providers may store and process data in data centers outside your country, including the United States.
          By using Forever, you understand your data may be transferred there to provide the service.
        </LegalP>
      </LegalSection>

      <LegalSection>
        <LegalH2>6. Retention & Deletion</LegalH2>
        <LegalList>
          <li>We keep your data for as long as your account exists.</li>
          <li>
            <strong>Unpairing</strong> permanently deletes the memories and drawings shared between you and your
            partner, for both of you.
          </li>
          <li>
            <strong>Deleting your account</strong> (Me tab → Delete Account) permanently deletes your profile, content,
            uploaded photos, and shared couple data, and unpairs you from your partner. Copies may remain in encrypted
            backups for a short period before they are overwritten.
          </li>
          <li>
            Deleting your account does not cancel an App Store subscription. Manage subscriptions in iOS Settings →
            your name → Subscriptions.
          </li>
        </LegalList>
      </LegalSection>

      <LegalSection>
        <LegalH2>7. Your Rights & Choices</LegalH2>
        <LegalP>
          Depending on where you live (for example under Quebec Law 25, the GDPR, or the CCPA/CPRA), you may have the
          right to access, correct, delete, or receive a copy of your personal information, and to withdraw consent.
          You can edit your profile in the app, change location, photo, and notification permissions in iOS Settings,
          delete your account in the app, or email us to make a request.
        </LegalP>
      </LegalSection>

      <LegalSection>
        <LegalH2>8. Age Requirement</LegalH2>
        <LegalP>
          Forever is intended for people aged 16 and older. We do not knowingly collect personal information from
          anyone under 16. If we learn that we have, we will delete it.
        </LegalP>
      </LegalSection>

      <LegalSection>
        <LegalH2>9. Changes to This Policy</LegalH2>
        <LegalP>
          We may update this policy from time to time. We will change the effective date above and, for significant
          changes, let you know in the app.
        </LegalP>
      </LegalSection>

      <LegalSection>
        <LegalH2>10. Contact</LegalH2>
        <LegalP>For privacy questions or requests, contact us at:</LegalP>
        <LegalP className="mt-4">
          Email: <LegalEmailLink email={SUPPORT_EMAIL} />
        </LegalP>
      </LegalSection>
    </LegalProse>
  )
}
