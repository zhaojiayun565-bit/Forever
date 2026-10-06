import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4"

const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!)
const revenueCatSecretKey = Deno.env.get("REVENUECAT_SECRET_API_KEY")!
const webhookAuth = Deno.env.get("REVENUECAT_WEBHOOK_AUTH")!
const entitlementId = Deno.env.get("REVENUECAT_ENTITLEMENT_ID") ?? "pro"

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

type PremiumState = { is_premium: boolean; premium_expires_at: string | null }

type RevenueCatEntitlement = {
  expires_date: string | null
  grace_period_expires_date?: string | null
}

type RevenueCatWebhookEvent = {
  app_user_id?: string
  original_app_user_id?: string
  aliases?: string[]
  transferred_from?: string[]
  transferred_to?: string[]
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } })
}

/** Reads the subscriber's entitlement from RevenueCat, the source of truth for purchases. */
async function fetchPremiumState(userId: string): Promise<PremiumState> {
  const response = await fetch(`https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(userId)}`, {
    headers: { Authorization: `Bearer ${revenueCatSecretKey}` },
  })
  if (!response.ok) throw new Error(`RevenueCat ${response.status}: ${await response.text()}`)

  const { subscriber } = await response.json()
  const entitlement = subscriber?.entitlements?.[entitlementId] as RevenueCatEntitlement | undefined
  if (!entitlement) return { is_premium: false, premium_expires_at: null }

  const expiries = [entitlement.expires_date, entitlement.grace_period_expires_date]
    .filter((date): date is string => !!date)
    .map((date) => new Date(date).getTime())
  const lifetime = entitlement.expires_date == null
  const latestExpiry = expiries.length ? Math.max(...expiries) : null
  const active = lifetime || (latestExpiry != null && latestExpiry > Date.now())

  return {
    is_premium: active,
    premium_expires_at: active && !lifetime && latestExpiry != null ? new Date(latestExpiry).toISOString() : null,
  }
}

/** Writes RevenueCat state onto the user's profile with service-role privileges. */
async function syncUser(userId: string): Promise<PremiumState> {
  const state = await fetchPremiumState(userId)
  const { error } = await supabase
    .from("profiles")
    .update({ ...state, premium_updated_at: new Date().toISOString() })
    .eq("id", userId)
  if (error) throw new Error(`Profile update failed: ${error.message}`)
  return state
}

/** RevenueCat webhook: re-sync every Supabase user referenced by the event (incl. transfers). */
async function handleWebhook(event: RevenueCatWebhookEvent): Promise<Response> {
  const ids = new Set(
    [
      event.app_user_id,
      event.original_app_user_id,
      ...(event.aliases ?? []),
      ...(event.transferred_from ?? []),
      ...(event.transferred_to ?? []),
    ].filter((id): id is string => !!id && uuidPattern.test(id)),
  )
  for (const id of ids) await syncUser(id)
  return json({ synced: [...ids] })
}

Deno.serve(async (req) => {
  try {
    const authorization = req.headers.get("Authorization") ?? ""

    if (webhookAuth && authorization === webhookAuth) {
      const body = await req.json()
      return await handleWebhook(body.event ?? {})
    }

    const token = authorization.replace(/^Bearer\s+/i, "")
    const { data, error } = await supabase.auth.getUser(token)
    if (error || !data.user) return json({ error: "Unauthorized" }, 401)

    return json(await syncUser(data.user.id))
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error)
    console.error("revenuecat-sync error:", message)
    return json({ error: message }, 500)
  }
})
