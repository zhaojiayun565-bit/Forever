import { SUPPORT_EMAIL } from "@/lib/support-email"

export const TERMS_HTML = `<h1 class="text-5xl font-bold text-gray-900 mb-8">Terms of Service</h1>
<div class="prose prose-lg max-w-none text-gray-700 space-y-12">
<p class="text-sm text-gray-500 mb-8"><strong>Effective Date:</strong> June 3, 2026</p>

<section>
<h2 class="text-2xl font-bold text-gray-900 mb-4">1. Agreement to Terms</h2>
<h3 class="text-xl font-semibold text-gray-900 mb-3 mt-4">1.1 Standard EULA Applies</h3>
<p>The &quot;Forever: App for Couples&quot; mobile application (the &quot;App&quot;) is licensed to you under the standard Apple Licensed Application End User License Agreement (Standard EULA). By using the App, you agree to be bound by the Standard EULA (<a href="https://www.apple.com/legal/internet-services/itunes/dev/stdeula/" target="_blank" rel="noopener noreferrer" class="text-[#F67939] hover:underline">https://www.apple.com/legal/internet-services/itunes/dev/stdeula/</a>).</p>
<h3 class="text-xl font-semibold text-gray-900 mb-3 mt-4">1.2 Supplemental Terms</h3>
<p>These Terms of Service (&quot;Terms&quot;) supplement the Standard EULA. If there is a conflict, the Standard EULA controls regarding the application license, and these Terms shall control regarding specific App features (subscriptions, user pairing, real-time synchronization, and liability).</p>
<h3 class="text-xl font-semibold text-gray-900 mb-3 mt-4">1.3 Age Requirement</h3>
<p>You must be at least 16 years of age to download, access, or use &quot;Forever: App for Couples&quot;. By using the App, you represent and warrant that you are at least 16 years old and meet the minimum legal age of digital consent in your jurisdiction. If you are under 16, you are strictly prohibited from using the App.</p>
</section>

<section>
<h2 class="text-2xl font-bold text-gray-900 mb-4">2. Description of Service &amp; Real-Time Synchronization</h2>
<p>&quot;Forever: App for Couples&quot; is a shared digital space for couples featuring real-time drawing boards, shared widgets, and memory mapping.</p>
<h3 class="text-xl font-semibold text-gray-900 mb-3 mt-4">2.1 User Pairing &amp; Connectivity</h3>
<p>The App relies on a multi-user pairing architecture. To use the shared features, you must link your account with your partner&apos;s account using a unique pairing code. Real-time features require an active internet connection to synchronize data via our cloud infrastructure.</p>
<h3 class="text-xl font-semibold text-gray-900 mb-3 mt-4">2.2 Unpairing &amp; Local State Deletion</h3>
<p>You or your partner may choose to unpair your devices at any time. Unpairing is a destructive action regarding your shared space. Upon unpairing:</p>
<ul class="list-disc pl-6 space-y-2 mt-4">
<li>Your local device state will clear its connection parameters.</li>
<li>Shared active states (like live drawing boards) will disconnect.</li>
<li>You are responsible for executing the unpair function within the app settings to clean up local cache. We are not liable for residual data appearing if an unpair action fails due to local network errors, device cold-starts, or unexpected client crashes.</li>
</ul>
</section>

<section>
<h2 class="text-2xl font-bold text-gray-900 mb-4">3. Subscriptions &amp; Purchases</h2>
<p>The App offers premium feature upgrades via auto-renewing subscriptions billed on a weekly or annual basis.</p>
<p class="mt-4"><strong>Payment:</strong> Charged to your Apple ID at confirmation of purchase. Prices vary by region and are managed through Apple App Store localization.</p>
<p class="mt-4"><strong>Auto-Renewal:</strong> Subscriptions renew automatically unless canceled at least 24 hours before the end of the current billing cycle.</p>
<p class="mt-4"><strong>Management &amp; Cancellations:</strong> All transactions, renewals, and cancellations are handled exclusively by Apple. We cannot issue refunds or manage your subscription billing status directly.</p>
</section>

<section>
<h2 class="text-2xl font-bold text-gray-900 mb-4">4. Intellectual Property &amp; User Content</h2>
<p>You and your partner retain full ownership of the text, drawings, and photos (&quot;User Content&quot;) you create within the App. By using the shared features, you grant us a narrow, technical, non-exclusive license to host, store, and transmit your User Content solely to facilitate the real-time syncing of data between your device and your partner&apos;s device.</p>
<p class="mt-4">All rights, title, and interest in the App&apos;s code, UI design, animations, layouts, and branding belong exclusively to the developer.</p>
</section>

<section>
<h2 class="text-2xl font-bold text-gray-900 mb-4">5. Limitation of Liability</h2>
<p>To the maximum extent permitted by law, &quot;Forever: App for Couples&quot; is provided &quot;AS IS&quot;. We do not guarantee uninterrupted, real-time connectivity. We are not liable for:</p>
<ul class="list-disc pl-6 space-y-2 mt-4">
<li>Data synchronization failures, server downtime, or loss of drawings/memories.</li>
<li>Any relationship disruptions, emotional distress, or real-world consequences resulting from your use of the App, data delivery failures, or the unpairing of accounts.</li>
<li>Network data charges incurred from real-time asset streaming.</li>
</ul>
</section>

<section>
<h2 class="text-2xl font-bold text-gray-900 mb-4">6. Governing Law &amp; Dispute Resolution</h2>
<p>These Terms shall be governed by and construed in accordance with the laws of the Province of Quebec, Canada, without regard to conflict of law principles. Any legal action or proceeding arising under these Terms will be brought exclusively in the courts located in Montreal, Quebec, Canada.</p>
<p class="mt-4"><strong>For users residing in the United States:</strong> You agree that any dispute arising out of or relating to this App shall be resolved through binding, individual arbitration, and you waive your right to participate in a class-action lawsuit or class-wide arbitration.</p>
</section>

<section>
<h2 class="text-2xl font-bold text-gray-900 mb-4">7. Contact</h2>
<p>Support Email: <a href="mailto:${SUPPORT_EMAIL}" class="text-[#F67939] hover:underline">${SUPPORT_EMAIL}</a></p>
</section>
</div>`
