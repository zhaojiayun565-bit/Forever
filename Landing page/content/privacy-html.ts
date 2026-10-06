import { SUPPORT_EMAIL } from "@/lib/support-email"

export const PRIVACY_HTML = `<h1 class="text-5xl font-bold text-gray-900 mb-8">Privacy Policy</h1>
<div class="prose prose-lg max-w-none text-gray-700 space-y-12">
<p class="text-sm text-gray-500 mb-8"><strong>Effective Date:</strong> June 3, 2026</p>

<section>
<h2 class="text-2xl font-bold text-gray-900 mb-4">1. Privacy Philosophy &amp; Governance</h2>
<p>&quot;Forever: App for Couples&quot; is built to protect the intimate data shared between partners. We do not sell your personal data to advertisers, and we minimize data collection to only what is technically required to run a real-time, paired application.</p>
<p class="mt-4"><strong>Privacy Officer:</strong> Under local data protection acts (including Quebec Law 25), the person responsible for data protection is the App Founder. You can reach them at the contact email below.</p>
</section>

<section>
<h2 class="text-2xl font-bold text-gray-900 mb-4">2. Information We Collect &amp; Processing Purpose</h2>
<p>To link two devices together and sync drawings, maps, and widgets instantly, we collect and process the following:</p>
<ul class="list-disc pl-6 space-y-2 mt-4">
<li><strong>Anonymous Account Identifiers:</strong> We use anonymous authentication tokens to safely route data packages to you and your partner. We do not require your real name or phone number to set up an account.</li>
<li><strong>User-Generated Shared Content:</strong> Drawings, canvas paths, map coordinates for shared memories, and widget assets. This data is stored in secure, private cloud tables dedicated to your paired session.</li>
<li><strong>Real-time Connection State:</strong> Temporary indicators required to let the cloud infrastructure know if you or your partner are online to receive live updates.</li>
<li><strong>App Diagnostics &amp; Performance Analytics:</strong> We track anonymous performance logs and crash metadata to debug user interface hitches, network synchronization failures, and UI animation lag.</li>
</ul>
</section>

<section>
<h2 class="text-2xl font-bold text-gray-900 mb-4">3. Data Storage &amp; Cross-Border Transfers</h2>
<p>Our cloud backend infrastructure is powered by Supabase and Google Firebase. While your data is protected by strict row-level security constraints (ensuring only you and your paired partner can access your data rows), please note that data may be transferred to and processed in secure cloud data centers located outside of your resident territory or country (including the United States). By using the App, you consent to this cross-border transfer necessary to execute the real-time application sync.</p>
</section>

<section>
<h2 class="text-2xl font-bold text-gray-900 mb-4">4. Privacy by Default &amp; Your Rights</h2>
<p>In accordance with modern privacy frameworks (such as Quebec Law 25, Europe&apos;s GDPR, and California&apos;s CCPA/CPRA), you have the following rights:</p>
<ul class="list-disc pl-6 space-y-2 mt-4">
<li><strong>Privacy by Default:</strong> We do not track your device for cross-app behavioral advertising purposes. Any non-essential analytical tracking is disabled by default.</li>
<li><strong>Right to Access &amp; Portability:</strong> You can request a copy of your stored database records at any time.</li>
<li><strong>Right to Deletion:</strong> When you choose to permanently wipe your data, or if you unpair and submit a deletion request, we will expunge your shared data records from our active cloud databases.</li>
<li><strong>Minors:</strong> &quot;Forever: App for Couples&quot; is strictly rated for users aged 16 and older. We do not knowingly collect, process, or store personal information from individuals under 16 years of age. If we discover that an account has been created by anyone under 16, we will immediately expunge all associated data from our cloud infrastructure.</li>
</ul>
</section>

<section>
<h2 class="text-2xl font-bold text-gray-900 mb-4">5. Third-Party Service Providers</h2>
<p>We partner with a minimal number of trusted infrastructure and service providers to securely run the App:</p>
<ul class="list-disc pl-6 space-y-2 mt-4">
<li><strong>Supabase:</strong> Real-time web socket data routing and secure database storage.</li>
<li><strong>Google Firebase:</strong> App configuration, performance diagnostics, crash logging, and cloud infrastructure synchronization.</li>
<li><strong>RevenueCat:</strong> Subscription state validation, transaction verification, and entitlement tracking.</li>
<li><strong>Apple App Store:</strong> Identity token validation, transaction management, and secure payment processing.</li>
</ul>
</section>

<section>
<h2 class="text-2xl font-bold text-gray-900 mb-4">6. Data Retention</h2>
<p>We retain your shared data only for as long as your account remains active and paired. If you completely delete the app or remain inactive for an extended period, we reserve the right to scrub old, unlinked real-time drawing caches to optimize server overhead.</p>
</section>

<section>
<h2 class="text-2xl font-bold text-gray-900 mb-4">7. Contact</h2>
<p>For any data privacy inquiries or to exercise your rights, contact our Privacy Officer at:</p>
<p class="mt-4">Email: <a href="mailto:${SUPPORT_EMAIL}" class="text-[#F67939] hover:underline">${SUPPORT_EMAIL}</a></p>
</section>
</div>`
