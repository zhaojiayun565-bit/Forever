import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4"
import { create } from "https://deno.land/x/djwt@v2.9.1/mod.ts"

const supabaseUrl = Deno.env.get("SUPABASE_URL")!
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
const supabase = createClient(supabaseUrl, supabaseServiceKey)

type AlertType =
  | "note"
  | "message"
  | "drawing_started"
  | "question_reveal"
  | "wallpaper"
  | "streak_reminder"

type AlertPushEvent = { type: AlertType; title: string; body: string; route: string; questionId?: string }
type LocationPushEvent = { type: "location" }
type PushEvent = AlertPushEvent | LocationPushEvent

type CoupleRow = {
  id: string
  user1_id: string
  user2_id: string
  board_wallpaper_url?: string | null
  board_wallpaper_updated_by?: string | null
}

type CoupleAnswerRow = {
  id: string
  couple_id: string
  question_id: string
  partner_a_id: string
  partner_a_response?: string | null
  partner_b_id: string
  partner_b_response?: string | null
}

type ProfileRow = {
  id: string
  display_name?: string | null
  device_token?: string | null
  latitude?: number | null
  longitude?: number | null
  latest_note_url?: string | null
  latest_message?: string | null
  drawing_started_at?: string | null
}

type DirectPushPayload = {
  mode: "direct"
  recipient_id: string
  title: string
  body: string
  type: AlertType
  route: string
  question_id?: string
}

function locationChanged(record: Record<string, unknown>, oldRecord: Record<string, unknown>): boolean {
  const lat = record.latitude as number | null | undefined
  const lon = record.longitude as number | null | undefined
  if (lat == null || lon == null) return false
  const oldLat = oldRecord.latitude as number | null | undefined
  const oldLon = oldRecord.longitude as number | null | undefined
  if (oldLat == null || oldLon == null) return true
  const threshold = 0.0005
  return Math.abs(lat - oldLat) > threshold || Math.abs(lon - oldLon) > threshold
}

function distanceMiles(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const toRad = (deg: number) => (deg * Math.PI) / 180
  const earthRadiusMeters = 6_371_000
  const dLat = toRad(lat2 - lat1)
  const dLon = toRad(lon2 - lon1)
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2
  const meters = earthRadiusMeters * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  return meters / 1609.344
}

let cachedJwt: { token: string; expiresAt: number } | null = null

async function getApnsJwt(): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  if (cachedJwt && cachedJwt.expiresAt > now + 60) return cachedJwt.token
  const teamId = Deno.env.get("APPLE_TEAM_ID")!
  const keyId = Deno.env.get("APPLE_KEY_ID")!
  const privateKeyStr = Deno.env.get("APPLE_P8_KEY")!
  const pemContents = privateKeyStr
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "")
  const binaryDerString = atob(pemContents)
  const binaryDer = new Uint8Array([...binaryDerString].map((char) => char.charCodeAt(0)))
  const key = await crypto.subtle.importKey(
    "pkcs8", binaryDer.buffer, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]
  )
  const token = await create({ alg: "ES256", kid: keyId }, { iss: teamId, iat: now }, key)
  cachedJwt = { token, expiresAt: now + 3000 }
  return token
}

async function sendApns(
  deviceToken: string,
  pushBody: Record<string, unknown>,
  pushType: "alert" | "background"
): Promise<Response> {
  const bundleId = Deno.env.get("APPLE_BUNDLE_ID")!
  const apnsHost = Deno.env.get("APPLE_APNS_HOST") ?? "api.sandbox.push.apple.com"
  const jwt = await getApnsJwt()
  const pushResponse = await fetch(`https://${apnsHost}/3/device/${deviceToken}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${jwt}`,
      "apns-topic": bundleId,
      "apns-push-type": pushType,
      "apns-priority": pushType === "alert" ? "10" : "5",
    },
    body: JSON.stringify(pushBody),
  })
  if (!pushResponse.ok) {
    const errText = await pushResponse.text()
    console.error("APNs Error:", errText)
    return new Response(`APNs error: ${errText}`, { status: 500 })
  }
  return new Response(JSON.stringify({ success: true }), { status: 200 })
}

async function fetchDeviceToken(userId: string): Promise<string | null> {
  const { data, error } = await supabase.from("profiles").select("device_token").eq("id", userId).single()
  if (error || !data?.device_token) return null
  return data.device_token
}

async function sendAlertToRecipient(
  recipientId: string,
  event: AlertPushEvent,
  extras: Record<string, unknown> = {}
): Promise<Response> {
  const deviceToken = await fetchDeviceToken(recipientId)
  if (!deviceToken) return new Response("No device token.", { status: 200 })
  const pushBody: Record<string, unknown> = {
    aps: { alert: { title: event.title, body: event.body }, sound: "default", "content-available": 1 },
    type: event.type,
    route: event.route,
    ...extras,
  }
  if (event.questionId) pushBody.question_id = event.questionId
  return await sendApns(deviceToken, pushBody, "alert")
}

async function handleProfilesWebhook(record: ProfileRow, oldRecord: Record<string, unknown>): Promise<Response> {
  const senderName = (record.display_name || "Your partner").trim()
  let event: PushEvent | null = null
  if (record.latest_note_url && record.latest_note_url !== oldRecord.latest_note_url) {
    event = { type: "note", title: "New Drawing", body: `${senderName} sent you a drawing!`, route: "drawingboard" }
  } else if (record.latest_message && record.latest_message !== oldRecord.latest_message) {
    event = { type: "message", title: senderName, body: record.latest_message!, route: "drawingboard" }
  } else if (record.drawing_started_at && record.drawing_started_at !== oldRecord.drawing_started_at) {
    event = { type: "drawing_started", title: `${senderName} is drawing`, body: "Tap to join them on the board", route: "drawingboard" }
  } else if (locationChanged(record as unknown as Record<string, unknown>, oldRecord)) {
    event = { type: "location" }
  }
  if (!event) return new Response("No syncable change, ignoring.", { status: 200 })

  const { data: couple, error: coupleError } = await supabase
    .from("couples").select("*")
    .or(`user1_id.eq.${record.id},user2_id.eq.${record.id}`)
    .order("created_at", { ascending: true }).limit(1).single()
  if (coupleError || !couple) throw new Error("Couple not found")

  const partnerId = couple.user1_id === record.id ? couple.user2_id : couple.user1_id
  const { data: partner, error: partnerError } = await supabase
    .from("profiles").select("device_token, latitude, longitude").eq("id", partnerId).single()
  if (partnerError || !partner?.device_token) return new Response("No device token.", { status: 200 })

  if (event.type === "location") {
    let partnerDistance: number | null = null
    if (partner.latitude != null && partner.longitude != null && record.latitude != null && record.longitude != null) {
      partnerDistance = distanceMiles(partner.latitude, partner.longitude, record.latitude, record.longitude)
    }
    return await sendApns(partner.device_token, {
      aps: { "content-available": 1 },
      type: "location",
      partner_latitude: record.latitude,
      partner_longitude: record.longitude,
      partner_distance: partnerDistance,
    }, "background")
  }

  return await sendApns(partner.device_token, {
    aps: { alert: { title: event.title, body: event.body }, sound: "default", "content-available": 1 },
    type: event.type,
    route: event.route,
    note_url: record.latest_note_url,
    latest_message: record.latest_message,
  }, "alert")
}

async function handleCoupleAnswersWebhook(record: CoupleAnswerRow): Promise<Response> {
  const aAnswered = record.partner_a_response != null
  const bAnswered = record.partner_b_response != null
  if (aAnswered === bAnswered) return new Response("Not a single-answer state, ignoring.", { status: 200 })

  const { data: question, error: questionError } = await supabase
    .from("questions").select("is_daily").eq("id", record.question_id).single()
  if (questionError || !question?.is_daily) return new Response("Not a daily question, ignoring.", { status: 200 })

  const actorId = aAnswered ? record.partner_a_id : record.partner_b_id
  const recipientId = aAnswered ? record.partner_b_id : record.partner_a_id
  const { data: actor, error: actorError } = await supabase.from("profiles").select("display_name").eq("id", actorId).single()
  if (actorError) throw new Error("Actor profile not found")
  const senderName = (actor?.display_name || "Your partner").trim()

  return await sendAlertToRecipient(recipientId, {
    type: "question_reveal",
    title: "Daily Question",
    body: `${senderName} just answered today's question! 👀 Answer yours to unlock what they said.`,
    route: "home",
    questionId: record.question_id,
  })
}

async function handleCouplesWebhook(record: CoupleRow, oldRecord: CoupleRow): Promise<Response> {
  if (record.board_wallpaper_url === oldRecord.board_wallpaper_url) {
    return new Response("Wallpaper unchanged, ignoring.", { status: 200 })
  }
  if (!record.board_wallpaper_updated_by) return new Response("No wallpaper actor, ignoring.", { status: 200 })

  const actorId = record.board_wallpaper_updated_by
  const recipientId = record.user1_id === actorId ? record.user2_id : record.user1_id
  const { data: actor, error: actorError } = await supabase.from("profiles").select("display_name").eq("id", actorId).single()
  if (actorError) throw new Error("Actor profile not found")
  const senderName = (actor?.display_name || "Your partner").trim()

  return await sendAlertToRecipient(recipientId, {
    type: "wallpaper",
    title: "Drawing Board",
    body: `🎨 ${senderName} just changed your board's wallpaper. Open it to check it out!`,
    route: "drawingboard",
  })
}

async function handleDirectPush(payload: DirectPushPayload): Promise<Response> {
  return await sendAlertToRecipient(payload.recipient_id, {
    type: payload.type,
    title: payload.title,
    body: payload.body,
    route: payload.route,
    questionId: payload.question_id,
  }, payload.question_id ? { question_id: payload.question_id } : {})
}

serve(async (req) => {
  try {
    const payload = await req.json()
    if (payload.mode === "direct") return await handleDirectPush(payload as DirectPushPayload)

    const table = payload.table as string | undefined
    if (table === "profiles") return await handleProfilesWebhook(payload.record as ProfileRow, payload.old_record ?? {})
    if (table === "couple_answers") return await handleCoupleAnswersWebhook(payload.record as CoupleAnswerRow)
    if (table === "couples") return await handleCouplesWebhook(payload.record as CoupleRow, (payload.old_record ?? {}) as CoupleRow)

    if (payload.record?.id) {
      return await handleProfilesWebhook(payload.record as ProfileRow, payload.old_record ?? {})
    }
    return new Response("Unknown payload, ignoring.", { status: 200 })
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error)
    return new Response(JSON.stringify({ error: message }), { status: 400 })
  }
})
