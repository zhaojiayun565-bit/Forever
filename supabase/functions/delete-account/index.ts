import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4"
import { create } from "https://deno.land/x/djwt@v2.9.1/mod.ts"

const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!)

const appleTeamId = Deno.env.get("APPLE_TEAM_ID")
const appleClientId = Deno.env.get("APPLE_BUNDLE_ID")
const siwaKeyId = Deno.env.get("APPLE_SIWA_KEY_ID") ?? Deno.env.get("APPLE_KEY_ID")
const siwaPrivateKey = Deno.env.get("APPLE_SIWA_P8_KEY") ?? Deno.env.get("APPLE_P8_KEY")
const revenueCatSecretKey = Deno.env.get("REVENUECAT_SECRET_API_KEY")

const storageBatchSize = 100

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } })
}

/** ES256 client secret for Apple's token endpoints, signed with a Sign in with Apple key. */
async function appleClientSecret(): Promise<string> {
  const pem = siwaPrivateKey!
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "")
  const der = Uint8Array.from(atob(pem), (char) => char.charCodeAt(0))
  const key = await crypto.subtle.importKey("pkcs8", der.buffer, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"])
  const now = Math.floor(Date.now() / 1000)
  return await create(
    { alg: "ES256", kid: siwaKeyId! },
    { iss: appleTeamId!, iat: now, exp: now + 300, aud: "https://appleid.apple.com", sub: appleClientId! },
    key,
  )
}

/** Exchanges the fresh authorization code for a refresh token and revokes it (Apple account-deletion requirement). */
async function revokeAppleToken(authorizationCode: string): Promise<boolean> {
  if (!appleTeamId || !appleClientId || !siwaKeyId || !siwaPrivateKey) return false
  const clientSecret = await appleClientSecret()

  const tokenResponse = await fetch("https://appleid.apple.com/auth/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: appleClientId,
      client_secret: clientSecret,
      code: authorizationCode,
      grant_type: "authorization_code",
    }),
  })
  if (!tokenResponse.ok) {
    console.error("Apple token exchange failed:", await tokenResponse.text())
    return false
  }
  const { refresh_token: refreshToken } = await tokenResponse.json()
  if (!refreshToken) return false

  const revokeResponse = await fetch("https://appleid.apple.com/auth/revoke", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: appleClientId,
      client_secret: clientSecret,
      token: refreshToken,
      token_type_hint: "refresh_token",
    }),
  })
  if (!revokeResponse.ok) console.error("Apple revoke failed:", await revokeResponse.text())
  return revokeResponse.ok
}

/** Removes the user's uploads and their couple's shared folder from every bucket. */
async function deleteStorageObjects(userId: string): Promise<number> {
  const { data, error } = await supabase.rpc("account_storage_objects", { p_user_id: userId })
  if (error) throw new Error(`Storage listing failed: ${error.message}`)

  const byBucket = new Map<string, string[]>()
  for (const { bucket_id, name } of (data ?? []) as { bucket_id: string; name: string }[]) {
    byBucket.set(bucket_id, [...(byBucket.get(bucket_id) ?? []), name])
  }

  let removed = 0
  for (const [bucket, names] of byBucket) {
    for (let i = 0; i < names.length; i += storageBatchSize) {
      const batch = names.slice(i, i + storageBatchSize)
      const { error: removeError } = await supabase.storage.from(bucket).remove(batch)
      if (removeError) throw new Error(`Storage delete failed (${bucket}): ${removeError.message}`)
      removed += batch.length
    }
  }
  return removed
}

/** Deletes the RevenueCat customer record; purchases stay with the Apple ID and can be restored. */
async function deleteRevenueCatCustomer(userId: string): Promise<boolean> {
  if (!revenueCatSecretKey) return false
  const response = await fetch(`https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(userId)}`, {
    method: "DELETE",
    headers: { Authorization: `Bearer ${revenueCatSecretKey}` },
  })
  if (!response.ok && response.status !== 404) console.error("RevenueCat delete failed:", await response.text())
  return response.ok
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405)
  try {
    const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "")
    const { data: userData, error: userError } = await supabase.auth.getUser(token)
    if (userError || !userData.user) return json({ error: "Unauthorized" }, 401)
    const userId = userData.user.id

    const body = await req.json().catch(() => ({}))
    const authorizationCode = typeof body.apple_authorization_code === "string" ? body.apple_authorization_code : null

    const appleRevoked = authorizationCode ? await revokeAppleToken(authorizationCode) : false
    const storageObjectsRemoved = await deleteStorageObjects(userId)
    const revenueCatDeleted = await deleteRevenueCatCustomer(userId)

    const { error: deleteError } = await supabase.auth.admin.deleteUser(userId)
    if (deleteError) throw new Error(`User delete failed: ${deleteError.message}`)

    return json({
      deleted: true,
      apple_revoked: appleRevoked,
      storage_objects_removed: storageObjectsRemoved,
      revenuecat_deleted: revenueCatDeleted,
    })
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error)
    console.error("delete-account error:", message)
    return json({ error: message }, 500)
  }
})
