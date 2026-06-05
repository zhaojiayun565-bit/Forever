import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4"
import { create } from "https://deno.land/x/djwt@v2.9.1/mod.ts"

const supabaseUrl = Deno.env.get("SUPABASE_URL")!
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
const supabase = createClient(supabaseUrl, supabaseServiceKey)

type AlertPushEvent = { type: "note" | "message" | "drawing_started"; title: string; body: string }
type LocationPushEvent = { type: "location" }
type PushEvent = AlertPushEvent | LocationPushEvent

/** Returns true when lat/lon changed by roughly 50m or more. */
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

/** Haversine distance in miles between two coordinates. */
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

serve(async (req) => {
  try {
    const payload = await req.json()
    const record = payload.record
    const oldRecord = payload.old_record ?? {}
    console.log("🔔 Webhook triggered for profile:", record.id)

    const senderName = (record.display_name || "Your partner").trim()
    let event: PushEvent | null = null

    if (record.latest_note_url && record.latest_note_url !== oldRecord.latest_note_url) {
      event = { type: "note", title: "New Drawing 🎨", body: `${senderName} sent you a drawing!` }
    } else if (record.latest_message && record.latest_message !== oldRecord.latest_message) {
      event = { type: "message", title: senderName, body: record.latest_message }
    } else if (record.drawing_started_at && record.drawing_started_at !== oldRecord.drawing_started_at) {
      event = { type: "drawing_started", title: `${senderName} is drawing ✏️`, body: "Tap to join them on the board" }
    } else if (locationChanged(record, oldRecord)) {
      event = { type: "location" }
    }

    if (!event) {
      return new Response("No syncable change, ignoring.", { status: 200 })
    }

    const { data: couple, error: coupleError } = await supabase
      .from("couples")
      .select("*")
      .or(`user1_id.eq.${record.id},user2_id.eq.${record.id}`)
      .single()

    if (coupleError || !couple) throw new Error("Couple not found")

    const partnerId = couple.user1_id === record.id ? couple.user2_id : couple.user1_id

    const { data: partner, error: partnerError } = await supabase
      .from("profiles")
      .select("device_token, latitude, longitude")
      .eq("id", partnerId)
      .single()

    if (partnerError || !partner?.device_token) {
      console.log("⏩ Partner has no device token. Skipping push.")
      return new Response("No device token.", { status: 200 })
    }

    const teamId = Deno.env.get("APPLE_TEAM_ID")!
    const keyId = Deno.env.get("APPLE_KEY_ID")!
    const privateKeyStr = Deno.env.get("APPLE_P8_KEY")!
    const bundleId = Deno.env.get("APPLE_BUNDLE_ID")!
    const apnsHost = Deno.env.get("APPLE_APNS_HOST") ?? "api.sandbox.push.apple.com"

    const pemContents = privateKeyStr
      .replace("-----BEGIN PRIVATE KEY-----", "")
      .replace("-----END PRIVATE KEY-----", "")
      .replace(/\s/g, "")

    const binaryDerString = atob(pemContents)
    const binaryDer = new Uint8Array([...binaryDerString].map((char) => char.charCodeAt(0)))

    const key = await crypto.subtle.importKey(
      "pkcs8",
      binaryDer.buffer,
      { name: "ECDSA", namedCurve: "P-256" },
      false,
      ["sign"]
    )

    const jwt = await create(
      { alg: "ES256", kid: keyId },
      { iss: teamId, iat: Math.floor(Date.now() / 1000) },
      key
    )

    const apnsUrl = `https://${apnsHost}/3/device/${partner.device_token}`

    let pushHeaders: Record<string, string>
    let pushBody: Record<string, unknown>

    if (event.type === "location") {
      let partnerDistance: number | null = null
      if (
        partner.latitude != null &&
        partner.longitude != null &&
        record.latitude != null &&
        record.longitude != null
      ) {
        partnerDistance = distanceMiles(
          partner.latitude,
          partner.longitude,
          record.latitude,
          record.longitude
        )
      }

      pushHeaders = {
        authorization: `bearer ${jwt}`,
        "apns-topic": bundleId,
        "apns-push-type": "background",
        "apns-priority": "5",
      }
      pushBody = {
        aps: { "content-available": 1 },
        type: "location",
        partner_latitude: record.latitude,
        partner_longitude: record.longitude,
        partner_distance: partnerDistance,
      }
      console.log("📤 Sending silent location push to Apple...")
    } else {
      pushHeaders = {
        authorization: `bearer ${jwt}`,
        "apns-topic": bundleId,
        "apns-push-type": "alert",
        "apns-priority": "10",
      }
      pushBody = {
        aps: {
          alert: {
            title: event.title,
            body: event.body,
          },
          sound: "default",
          "content-available": 1,
        },
        type: event.type,
        route: "drawingboard",
        note_url: record.latest_note_url,
        latest_message: record.latest_message,
      }
      console.log("📤 Sending alert push to Apple...")
    }

    const pushResponse = await fetch(apnsUrl, {
      method: "POST",
      headers: pushHeaders,
      body: JSON.stringify(pushBody),
    })

    if (!pushResponse.ok) {
      const errText = await pushResponse.text()
      console.error("🚨 Apple APNs Error:", errText)
      return new Response(`APNs error: ${errText}`, { status: 500 })
    }

    console.log("✅ Push successfully sent to Apple!")
    return new Response(JSON.stringify({ success: true }), { status: 200 })
  } catch (error) {
    console.error("🚨 Function Error:", error.message)
    return new Response(JSON.stringify({ error: error.message }), { status: 400 })
  }
})
