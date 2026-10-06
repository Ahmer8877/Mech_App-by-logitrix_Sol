# MechX OS Push Notification Setup

This module keeps the existing Supabase `notifications` table as the source of truth and adds OneSignal as the phone push-delivery layer.

## 1. OneSignal

Create/configure a OneSignal mobile app for MechX and obtain the **App ID**.

Put only the public App ID in the mobile `.env`:

```env
ONESIGNAL_APP_ID=YOUR_ONESIGNAL_APP_ID
```

Do **not** put the OneSignal REST API key in the Flutter app.

## 2. Supabase secrets

Set these secrets for the `send-push-notification` Edge Function:

- `ONESIGNAL_APP_ID`
- `ONESIGNAL_REST_API_KEY`
- `MECHX_NOTIFICATION_WEBHOOK_SECRET`

The REST API key and webhook secret must remain server-side.

## 3. Run the SQL patch

Run:

`supabase/notification_push_setup.sql`

in the Supabase SQL Editor.

It adds optional routing data to notifications and updates the existing booking/offer notification functions without removing the existing notification system.

## 4. Deploy the Edge Function

Deploy:

`supabase/functions/send-push-notification/index.ts`

using the Supabase CLI or your normal Supabase deployment workflow.

The function must keep JWT verification enabled. The database webhook should send a valid Supabase Authorization header and also send:

`x-mechx-webhook-secret: <same value as MECHX_NOTIFICATION_WEBHOOK_SECRET>`

## 5. Create a Database Webhook

In Supabase Dashboard, create a Database Webhook for:

- Table: `public.notifications`
- Event: `INSERT`
- Target: Edge Function `send-push-notification`

Add the required Authorization header and the `x-mechx-webhook-secret` header.

The webhook payload must include the inserted `record` object. The Edge Function reads `record.user_id`, `record.title`, `record.subtitle`, and `record.data`.

## 6. Test

Test in this order:

1. App open/foreground
2. App in background
3. App completely terminated
4. Tap notification
5. Verify the correct customer/mechanic receives it
6. Verify the in-app Notifications screen still contains the same notification

## Security

- `ONESIGNAL_REST_API_KEY` stays in Supabase Edge Function secrets.
- `MECHX_NOTIFICATION_WEBHOOK_SECRET` stays in Supabase/webhook configuration.
- `.env` is already excluded by the project's `.gitignore`.
- Existing Apple Auth and Gradle configuration should not be changed for this module.
