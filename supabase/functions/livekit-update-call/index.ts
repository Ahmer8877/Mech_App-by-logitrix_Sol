import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

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
    const action = body?.action as string | undefined;
    if (!sessionId || !["accept", "reject", "missed", "end"].includes(action)) {
      return out({ error: "Invalid request" }, 400);
    }

    const { data: session, error: sessionError } = await db
      .from("call_sessions")
      .select("*")
      .eq("id", sessionId)
      .single();

    if (sessionError || !session) return out({ error: "Call session not found" }, 404);
    if (session.caller_id !== user.id && session.callee_id !== user.id) {
      return out({ error: "Forbidden" }, 403);
    }

    if (action === "accept") {
      if (session.callee_id !== user.id) {
        return out({ error: "Only the recipient can accept a call" }, 403);
      }
      // Idempotent accept: a repeated request after realtime delay is harmless.
      if (session.status === "accepted") return out(session);
      if (session.status !== "ringing") {
        return out({ error: "Call is no longer ringing", status: session.status }, 409);
      }

      const { data: updated, error } = await db
        .from("call_sessions")
        .update({ status: "accepted", answered_at: new Date().toISOString() })
        .eq("id", sessionId)
        .eq("status", "ringing")
        .select()
        .maybeSingle();

      if (error) return out({ error: error.message }, 500);
      if (!updated) {
        const { data: latest } = await db.from("call_sessions").select("*").eq("id", sessionId).maybeSingle();
        if (latest?.status === "accepted") return out(latest);
        return out({ error: "Call changed before it could be accepted" }, 409);
      }
      return out(updated);
    }

    if (action === "missed") {
      // Only the caller may close an unanswered ringing call as missed.
      // This is used by the caller-side ring timeout and is idempotent.
      if (session.caller_id !== user.id) {
        return out({ error: "Only the caller can mark a call as missed" }, 403);
      }
      if (session.status === "missed") return out(session);
      if (session.status === "accepted") return out(session);
      if (session.status !== "ringing") {
        return out({ error: "Call is no longer ringing", status: session.status }, 409);
      }
      // Enforce the ring timeout on the server too; a modified client must not
      // be able to mark a call missed immediately after it starts ringing.
      const createdAtMs = Date.parse(session.created_at);
      if (!Number.isFinite(createdAtMs) || Date.now() - createdAtMs < 45_000) {
        return out({ error: "Call has not timed out yet", status: session.status }, 409);
      }

      const { data: updated, error } = await db
        .from("call_sessions")
        .update({ status: "missed", ended_at: new Date().toISOString() })
        .eq("id", sessionId)
        .eq("status", "ringing")
        .select()
        .maybeSingle();

      if (error) return out({ error: error.message }, 500);
      if (!updated) {
        const { data: latest } = await db
          .from("call_sessions")
          .select("*")
          .eq("id", sessionId)
          .maybeSingle();
        if (latest?.status === "missed" || latest?.status === "accepted") {
          return out(latest);
        }
        return out({ error: "Call changed before it could be marked missed" }, 409);
      }
      return out(updated);
    }

    if (action === "reject") {
      if (session.callee_id !== user.id) {
        return out({ error: "Only the recipient can reject a call" }, 403);
      }
      // Idempotent reject.
      if (session.status === "rejected") return out(session);
      if (session.status !== "ringing") {
        return out({ error: "Call is no longer ringing", status: session.status }, 409);
      }

      const { data: updated, error } = await db
        .from("call_sessions")
        .update({ status: "rejected", ended_at: new Date().toISOString() })
        .eq("id", sessionId)
        .eq("status", "ringing")
        .select()
        .maybeSingle();

      if (error) return out({ error: error.message }, 500);
      if (!updated) {
        const { data: latest } = await db.from("call_sessions").select("*").eq("id", sessionId).maybeSingle();
        if (latest?.status === "rejected") return out(latest);
        return out({ error: "Call changed before it could be rejected" }, 409);
      }
      return out(updated);
    }

    // End: either participant can end an active call. Repeating End is safe.
    if (["ended", "rejected", "missed"].includes(session.status)) return out(session);
    if (!["ringing", "accepted"].includes(session.status)) {
      return out({ error: "Call is not active", status: session.status }, 409);
    }

    const { data: updated, error } = await db
      .from("call_sessions")
      .update({ status: "ended", ended_at: new Date().toISOString() })
      .eq("id", sessionId)
      .in("status", ["ringing", "accepted"])
      .select()
      .maybeSingle();

    if (error) return out({ error: error.message }, 500);
    if (!updated) {
      const { data: latest } = await db.from("call_sessions").select("*").eq("id", sessionId).maybeSingle();
      if (latest && ["ended", "rejected", "missed"].includes(latest.status)) return out(latest);
      return out({ error: "Call changed before it could be ended" }, 409);
    }

    return out(updated);
  } catch (error) {
    return out({ error: error instanceof Error ? error.message : String(error) }, 500);
  }
});
