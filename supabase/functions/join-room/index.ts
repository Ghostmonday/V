/**
 * Join Room - LiveKit token generation
 * Secure endpoint for WebRTC room access
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "https://vibez.app",
  "Access-Control-Allow-Headers": "authorization, content-type",
};

// Manual LiveKit JWT token generation
async function generateLiveKitToken(
  apiKey: string,
  apiSecret: string,
  identity: string,
  name: string,
  room: string
): Promise<string> {
  const header = {
    alg: "HS256",
    typ: "JWT",
  };

  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: apiKey,
    sub: identity,
    iat: now,
    exp: now + 3600, // 1 hour
    video: {
      room: room,
      roomJoin: true,
      canPublish: true,
      canSubscribe: true,
    },
    name: name,
  };

  // Encode header and payload
  const encodeBase64Url = (data: Uint8Array): string => {
    return btoa(String.fromCharCode(...data))
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=/g, "");
  };

  const headerEncoded = encodeBase64Url(
    new TextEncoder().encode(JSON.stringify(header))
  );
  const payloadEncoded = encodeBase64Url(
    new TextEncoder().encode(JSON.stringify(payload))
  );

  // Create signature
  const signatureInput = `${headerEncoded}.${payloadEncoded}`;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(apiSecret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(signatureInput)
  );

  const signatureEncoded = encodeBase64Url(new Uint8Array(signature));

  return `${headerEncoded}.${payloadEncoded}.${signatureEncoded}`;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  try {
    // Verify JWT
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const token = authHeader.substring(7);
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      {
        global: {
          headers: { Authorization: authHeader },
        },
      }
    );

    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser(token);

    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Invalid token" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Parse request
    const body = await req.json();
    const { roomId, participantName } = body;

    if (!roomId || !participantName) {
      return new Response(
        JSON.stringify({ error: "Missing roomId or participantName" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Verify user has access to room
    const { data: room, error: roomError } = await supabase
      .from("rooms")
      .select("id, created_by, is_public")
      .eq("id", roomId)
      .single();

    if (roomError || !room) {
      return new Response(
        JSON.stringify({ error: "Room not found" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!room.is_public && room.created_by !== user.id) {
      return new Response(
        JSON.stringify({ error: "Access denied" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Generate LiveKit token
    const livekitUrl = Deno.env.get("LIVEKIT_URL");
    const livekitApiKey = Deno.env.get("LIVEKIT_API_KEY");
    const livekitApiSecret = Deno.env.get("LIVEKIT_API_SECRET");

    if (!livekitUrl || !livekitApiKey || !livekitApiSecret) {
      return new Response(
        JSON.stringify({ error: "LiveKit not configured" }),
        { status: 503, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const livekitToken = await generateLiveKitToken(
      livekitApiKey,
      livekitApiSecret,
      user.id,
      participantName,
      roomId
    );

    return new Response(
      JSON.stringify({
        url: livekitUrl,
        token: livekitToken,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
