import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-mechx-webhook-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const webhookSecret = Deno.env.get("MECHX_NOTIFICATION_WEBHOOK_SECRET");
    if (!webhookSecret || req.headers.get("x-mechx-webhook-secret") !== webhookSecret) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const appId = Deno.env.get("ONESIGNAL_APP_ID");
    const restApiKey = Deno.env.get("ONESIGNAL_REST_API_KEY");

    if (!appId || !restApiKey) {
      return new Response(JSON.stringify({ error: "OneSignal server secrets are not configured" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = await req.json();
    const record = body?.record ?? body;
    const userId = record?.user_id?.toString();
    const title = record?.title?.toString() ?? "MechX";
    const subtitle = record?.subtitle?.toString() ?? "You have a new notification.";
    const notificationData = record?.data && typeof record.data === "object"
      ? record.data
      : {};

    if (!userId) {
      return new Response(JSON.stringify({ error: "Notification user_id is required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const response = await fetch("https://api.onesignal.com/notifications", {
      method: "POST",
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        Authorization: `Key ${restApiKey}`,
      },
      body: JSON.stringify({
        app_id: appId,
        target_channel: "push",
        include_aliases: {
          external_id: [userId],
        },
        headings: { en: title },
        contents: { en: subtitle },
        data: notificationData,
      }),
    });

    const result = await response.json();

    return new Response(JSON.stringify({
      ok: response.ok,
      onesignal: result,
    }), {
      status: response.ok ? 200 : response.status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({
      error: error instanceof Error ? error.message : String(error),
    }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
