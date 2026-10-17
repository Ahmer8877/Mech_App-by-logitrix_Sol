import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const out = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
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
    if (!url || !anon || !service) return out({ error: "Supabase function secrets are not configured" }, 500);

    const userDb = createClient(url, anon, { global: { headers: { Authorization: auth } } });
    const db = createClient(url, service);
    const { data: { user }, error: authError } = await userDb.auth.getUser();
    if (authError || !user) return out({ error: "Unauthorized" }, 401);

    const body = await req.json().catch(() => null);
    const bookingId = body?.booking_id as string | undefined;
    if (!bookingId) return out({ error: "booking_id is required" }, 400);

    const { data: booking, error: bookingError } = await db
      .from("bookings")
      .select("id,customer_id,mechanic_id,status")
      .eq("id", bookingId)
      .single();
    if (bookingError || !booking) return out({ error: "Booking not found" }, 404);

    const isCustomer = booking.customer_id === user.id;
    const isMechanic = booking.mechanic_id === user.id;
    if ((!isCustomer && !isMechanic) || !booking.mechanic_id) return out({ error: "You are not a participant in this booking" }, 403);
    if (!["accepted", "on_the_way", "in_progress"].includes(booking.status)) {
      return out({ error: "Calling is available only for an active assigned booking" }, 409);
    }

    const callerId = user.id;
    const calleeId = isCustomer ? booking.mechanic_id : booking.customer_id;

    const { data: existing, error: existingError } = await db
      .from("call_sessions")
      .select("*")
      .eq("booking_id", booking.id)
      .in("status", ["ringing", "accepted"])
      .maybeSingle();
    if (existingError) return out({ error: existingError.message }, 500);
    if (existing) {
      // The other participant may already be ringing this user. Do not return
      // that session as if the current user initiated it: the outgoing UI
      // cannot accept/reject it and must not try to mark it missed.
      if (existing.caller_id !== callerId) {
        return out({
          error: "There is already an incoming or active call for this booking",
          session_id: existing.id,
          status: existing.status,
        }, 409);
      }
      return out(await addNames(db, existing));
    }

    const [{ data: callerProfile }, { data: calleeProfile }] = await Promise.all([
      db.from("profiles").select("full_name").eq("id", callerId).maybeSingle(),
      db.from("profiles").select("full_name").eq("id", calleeId).maybeSingle(),
    ]);
    const callerName = callerProfile?.full_name ?? "MechX user";
    const calleeName = calleeProfile?.full_name ?? "MechX user";

    const roomName = `mechx-call-${booking.id}-${crypto.randomUUID()}`;

    const { data: session, error: insertError } = await db
      .from("call_sessions")
      .insert({
        booking_id: booking.id,
        caller_id: callerId,
        callee_id: calleeId,
        room_name: roomName,
        status: "ringing",
      })
      .select()
      .single();

    if (insertError || !session) {
      if (insertError?.code === "23505") {
        const { data: concurrent } = await db
          .from("call_sessions")
          .select("*")
          .eq("booking_id", booking.id)
          .in("status", ["ringing", "accepted"])
          .maybeSingle();
        if (concurrent) {
          if (concurrent.caller_id !== callerId) {
            return out({
              error: "There is already an incoming or active call for this booking",
              session_id: concurrent.id,
              status: concurrent.status,
            }, 409);
          }
          return out(await addNames(db, concurrent));
        }
      }
      return out({ error: insertError?.message ?? "Could not start call" }, 500);
    }

    await db.from("notifications").insert({
      user_id: calleeId,
      title: "Incoming call",
      subtitle: `${callerName} is calling you`,
      icon_name: "phone_in_talk_outlined",
      data: {
        type: "incoming_call",
        booking_id: booking.id,
        call_session_id: session.id,
        caller_id: callerId,
        caller_name: callerName,
      },
    });

    return out({ ...session, caller_name: callerName, callee_name: calleeName });
  } catch (error) {
    return out({ error: error instanceof Error ? error.message : String(error) }, 500);
  }
});

async function addNames(db: any, session: any) {
  const [{ data: caller }, { data: callee }] = await Promise.all([
    db.from("profiles").select("full_name").eq("id", session.caller_id).maybeSingle(),
    db.from("profiles").select("full_name").eq("id", session.callee_id).maybeSingle(),
  ]);
  return {
    ...session,
    caller_name: caller?.full_name ?? "MechX user",
    callee_name: callee?.full_name ?? "MechX user",
  };
}
