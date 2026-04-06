import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4"
import { create } from "https://deno.land/x/djwt@v2.9.1/mod.ts"

// Initialize Supabase Client
const supabaseUrl = Deno.env.get("SUPABASE_URL")!
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
const supabase = createClient(supabaseUrl, supabaseServiceKey)

serve(async (req) => {
  try {
    // 1. Parse the incoming webhook payload
    const payload = await req.json()
    const record = payload.record // The user profile that just updated their note

    if (!record.latest_note_url) {
        return new Response("No note url, ignoring.", { status: 200 })
    }

    // 2. Find the couple row to identify the partner
    const { data: couple, error: coupleError } = await supabase
      .from("couples")
      .select("*")
      .or(`user1_id.eq.${record.id},user2_id.eq.${record.id}`)
      .single()

    if (coupleError || !couple) throw new Error("Couple not found")

    // Determine the partner's ID
    const partnerId = couple.user1_id === record.id ? couple.user2_id : couple.user1_id

    // 3. Fetch the Partner's Device Token
    const { data: partner, error: partnerError } = await supabase
      .from("profiles")
      .select("device_token")
      .eq("id", partnerId)
      .single()

    if (partnerError || !partner?.device_token) {
        return new Response("Partner has no device token. Cannot send push.", { status: 200 })
    }

    // 4. Generate the Apple APNs JWT (The Magic Key)
    const teamId = Deno.env.get("APPLE_TEAM_ID")!
    const keyId = Deno.env.get("APPLE_KEY_ID")!
    const privateKeyStr = Deno.env.get("APPLE_P8_KEY")!
    const bundleId = Deno.env.get("APPLE_BUNDLE_ID")! 

    // Format the private key
    const pemHeader = "-----BEGIN PRIVATE KEY-----"
    const pemFooter = "-----END PRIVATE KEY-----"
    const pushResponse = await fetch(apnsUrl, {
      method: "POST",
      headers: {
        "authorization": `bearer ${jwt}`,
        "apns-topic": bundleId,
        "apns-push-type": "background",
        "apns-priority": "5", 
      },
      body: JSON.stringify({
        aps: {
          "content-available": 1 
        },
        note_url: record.latest_note_url // WE PASS THE URL HERE
      })
    })
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

    // 5. Send the Silent Push to Apple's Servers
    // Note: We use api.development for testing on Simulators/local builds. For App Store, it's api.push.apple.com
    const apnsUrl = `https://api.sandbox.push.apple.com/3/device/${partner.device_token}`

    const pushResponse = await fetch(apnsUrl, {
      method: "POST",
      headers: {
        "authorization": `bearer ${jwt}`,
        "apns-topic": bundleId,
        "apns-push-type": "background",
        "apns-priority": "5", // 5 is required for background silent pushes
      },
      body: JSON.stringify({
        aps: {
          "content-available": 1 // THIS is what wakes up the partner's app silently
        }
      })
    })

    if (!pushResponse.ok) {
        const errText = await pushResponse.text()
        console.error("APNs Error:", errText)
        throw new Error(`Apple rejected the push: ${errText}`)
    }

    return new Response(JSON.stringify({ success: true, message: "Silent push sent!" }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    })

  } catch (error) {
    console.error("Error sending push:", error)
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { "Content-Type": "application/json" },
      status: 400,
    })
  }
})