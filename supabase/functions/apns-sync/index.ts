import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4"
import { create } from "https://deno.land/x/djwt@v2.9.1/mod.ts"

const supabaseUrl = Deno.env.get("SUPABASE_URL")!
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
const supabase = createClient(supabaseUrl, supabaseServiceKey)

serve(async (req) => {
  try {
    const payload = await req.json()
    const record = payload.record 
    console.log("🔔 Webhook triggered for profile:", record.id)

    if (!record.latest_note_url) {
        return new Response("No note url, ignoring.", { status: 200 })
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
      .select("device_token")
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

    const apnsUrl = `https://api.sandbox.push.apple.com/3/device/${partner.device_token}`

    console.log("📤 Sending silent push to Apple...")
    const pushResponse = await fetch(apnsUrl, {
      method: "POST",
      headers: {
        "authorization": `bearer ${jwt}`,
        "apns-topic": bundleId,
        "apns-push-type": "background",
        "apns-priority": "5", 
      },
      body: JSON.stringify({
        aps: { "content-available": 1 },
        note_url: record.latest_note_url
      })
    })

    if (!pushResponse.ok) {
        const errText = await pushResponse.text()
        console.error("🚨 Apple APNs Error:", errText)
        return new Response(`APNs error: ${errText}`, { status: 500 })
    }

    console.log("✅ Silent push successfully sent to Apple!")
    return new Response(JSON.stringify({ success: true }), { status: 200 })

  } catch (error) {
    console.error("🚨 Function Error:", error.message)
    return new Response(JSON.stringify({ error: error.message }), { status: 400 })
  }
})