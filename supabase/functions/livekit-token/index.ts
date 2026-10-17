import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { AccessToken } from "npm:livekit-server-sdk@2.19.1";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const out = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });

function normalizeLiveKitUrl(value: string): string {
  let url = value.trim().replace(/^"+|"+$/g, "").replace(/\/+$/, "");
  const parsed = new URL(url);

  if (parsed.protocol === "https:") {
    return `wss://${parsed.host}${parsed.pathname === "/" ? "" : parsed.pathname}`;
  }
  if (parsed.protocol === "http:") {
    return `ws://${parsed.host}${parsed.pathname === "/" ? "" : parsed.pathname}`;
  }
  if (parsed.protocol === "ws:" || parsed.protocol === "wss:") {
    return url;
  }
  throw new Error(`Invalid LIVEKIT_URL protocol: ${parsed.protocol}`);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return out({ error: "Method not allowed" }, 405);

  try {
    const auth = req.headers.get("Authorization");
    if (!auth) return out({ error: "Missing authorization" }, 401);

    const url = Deno.env.get("SUPABASE_URL");
    const anon = Deno.env.get("SUPABASE_ANON_KEY");
    const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!url || !anon || !service) {
      return out({ error: "Supabase function secrets are not configured" }, 500);
    }

    const userDb = createClient(url, anon, { global: { headers: { Authorization: auth } } });
    const db = createClient(url, service);
    const { data: { user }, error: authError } = await userDb.auth.getUser();
    if (authError || !user) return out({ error: "Unauthorized" }, 401);

    const body = await req.json().catch(() => null);
    const sessionId = body?.session_id as string | undefined;
    if (!sessionId) return out({ error: "session_id is required" }, 400);

    const { data: session, error: sessionError } = await db
      .from("call_sessions")
      .select("*")
      .eq("id", sessionId)
      .single();

    if (sessionError || !session) return out({ error: "Call session not found" }, 404);
    if (session.caller_id !== user.id && session.callee_id !== user.id) {
      return out({ error: "Forbidden" }, 403);
    }
    if (session.status !== "accepted") {
      return out({ error: "Call has not been accepted", status: session.status }, 409);
    }

    const key = Deno.env.get("LIVEKIT_API_KEY");
    const secret = Deno.env.get("LIVEKIT_API_SECRET");
    const rawServer = Deno.env.get("LIVEKIT_URL");
    if (!key || !secret || !rawServer) {
      return out({ error: "LiveKit server secrets are not configured" }, 500);
    }

    const server = normalizeLiveKitUrl(rawServer);
    const token = new AccessToken(key, secret, {
      identity: user.id,
      ttl: "1h",
    });

    token.addGrant({
      roomJoin: true,
      room: session.room_name,
      canPublish: true,
      canSubscribe: true,
    });

    return out({
      server_url: server,
      participant_token: await token.toJwt(),
      room_name: session.room_name,
      session_id: session.id,
    });
  } catch (error) {
    return out({ error: error instanceof Error ? error.message : String(error) }, 500);
  }
});
