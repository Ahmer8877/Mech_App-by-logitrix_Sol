# MechX — On-Demand Mechanic Marketplace

MechX is a Flutter mobile marketplace that connects customers who need vehicle repairs with mechanics who can respond to service requests, send offers, travel to the customer, communicate in-app, and complete jobs. The app uses Supabase for authentication and backend data, Riverpod for app state, Google Maps/location services for tracking and routes, OneSignal for push notifications, and LiveKit for internet voice calls.

> **Project status:** active development. Core customer/mechanic workflows and in-app voice calling are implemented in this repository. Run the checks and device-level test plan in this documentation before shipping a release. This README does not claim that every deployment or device combination has been independently tested.

## Contents

- [Features](#features)
- [Technology stack](#technology-stack)
- [Architecture](#architecture)
- [Project layout](#project-layout)
- [Requirements](#requirements)
- [Local setup](#local-setup)
- [Environment configuration](#environment-configuration)
- [Supabase setup](#supabase-setup)
- [Edge Functions and secrets](#edge-functions-and-secrets)
- [Maps and location](#maps-and-location)
- [Push notifications](#push-notifications)
- [Internet voice calling](#internet-voice-calling)
- [Database and realtime](#database-and-realtime)
- [Run, analyze, and build](#run-analyze-and-build)
- [Manual QA checklist](#manual-qa-checklist)
- [Security notes](#security-notes)
- [Troubleshooting](#troubleshooting)
- [Versioning and release](#versioning-and-release)
- [Known deployment-specific work](#known-deployment-specific-work)

## Features

### Customer
- Email/password authentication and role-based navigation.
- Customer profile and vehicle management.
- Browse/search services and view service details.
- Create a booking by selecting a vehicle, describing the issue, adding optional photos, and setting a location.
- Receive and review mechanic offers; accept an offer and follow the booking lifecycle.
- Booking history and pending-offer access, with cancellation where allowed by the booking state.
- Live map/tracking and route/distance display for active jobs.
- In-app chat, internet voice calls, call history, notifications, ratings/reviews, payment-method screens, and help/support screens.

### Mechanic
- Mechanic profile and verification-related screens.
- View nearby/open requests and inspect request details.
- Send offers with price and estimated arrival details.
- Navigate to customer and update job progress.
- Chat and internet voice calls with the customer during an eligible booking.
- Earnings, completed jobs, and rating-related views.

### Platform
- Supabase-backed relational data and realtime streams.
- Riverpod providers/repositories for app state and data access.
- Google Maps, geolocation, and server-side route computation.
- OneSignal push-notification integration.
- LiveKit internet voice calling with call-session Edge Functions.
- Light/dark theme and localization support (English/Urdu resources are in `assets/translations/`).

## Technology stack

| Area | Technology |
|---|---|
| Mobile UI | Flutter / Dart |
| State management | `flutter_riverpod` |
| Backend and authentication | Supabase Auth, PostgreSQL, Realtime, Storage, Edge Functions |
| Maps and location | `google_maps_flutter`, `geolocator`, Google Routes API via Edge Function |
| Push | OneSignal Flutter SDK and Supabase Edge Function |
| Voice | LiveKit Flutter SDK and Supabase Edge Functions |
| Configuration | `flutter_dotenv` for client configuration; Supabase function secrets for server secrets |
| Preferences | `shared_preferences` |
| Images | `image_picker`, `cached_network_image` |

Exact package versions are defined in `pubspec.yaml` and locked by `pubspec.lock`. Avoid upgrading versions casually during bug-fix or release work.

## Architecture

The app broadly follows this flow:

1. **Screens** render customer, mechanic, authentication, booking, map, chat, and call experiences.
2. **Riverpod providers** expose reactive state and connect screens to data/services.
3. **Repositories** isolate Supabase queries and operations for bookings, offers, vehicles, chat, locations, routes, notifications, media, and support.
4. **Supabase** stores application records and enforces access through Row-Level Security (RLS).
5. **Edge Functions** perform server-side tasks that must not expose secrets to the mobile client, including LiveKit token/session operations, route computation, and push delivery.

Typical booking lifecycle: customer creates request → mechanics view request and submit offers → customer accepts an offer → both parties coordinate using location/chat/call → mechanic completes job → customer can rate/review and booking appears in history. Exact status transitions are enforced by the current app/database implementation; check the relevant repository and schema before changing them.

## Project layout

```text
lib/
  cores/
    config/         # Supabase, dotenv, service radius configuration
    models/         # Profile, booking, vehicle, offer, chat, notification models
    providers/      # Riverpod state providers
    repositories/   # Supabase/data access layers
    services/       # Push notification and LiveKit call services
    theme/          # Colors and application themes
    utils/          # Friendly error handling and helpers
  screens/
    auth&role/      # Login, signup, role selection, password reset
    customer/       # Customer home, booking, service, tracking and history
    mechanic/       # Mechanic requests, offers, jobs and earnings
    call/           # Voice-call UI and call history
    notification/   # Notifications
    profile/        # Profile screens
    hepl&support/   # Help/support UI (directory spelling retained)
  widgets/          # Reusable UI and live map widgets
  utils/            # Input formatters
assets/
  icons/            # App launcher assets
  translations/     # Localization resources
supabase/
  functions/
    compute-route/          # Server-side route computation
    livekit-start-call/     # Call setup/session start
    livekit-token/          # LiveKit token generation
    livekit-update-call/    # Call state updates
    send-push-notification/ # OneSignal push delivery
  migrations/               # Versioned SQL migrations
  notification_push_setup.sql
supabase_schema.sql         # Main database schema/policies
```

## Requirements

- Flutter SDK compatible with `environment.sdk` in `pubspec.yaml` (this project currently declares Dart `^3.12.2`).
- Android Studio with a compatible Android SDK, Android build tools, and Java/Gradle versions compatible with the checked-in Android configuration.
- A Supabase project.
- Google Maps/Routes API project and API key(s).
- OneSignal app for push notifications.
- LiveKit project for internet voice calls.
- Physical Android devices are recommended for final incoming-call, notification, ringtone, and background-state testing. Emulator behavior can differ by OS and manufacturer.

## Local setup

1. Clone/download the repository and open the Flutter project root (the folder containing `pubspec.yaml`).
2. Install the Flutter SDK version compatible with this project and verify it with `flutter doctor`.
3. Create a local `.env` using [`.env.example`](.env.example). Never commit your real `.env`.
4. Configure Supabase, Google Maps, OneSignal, and LiveKit as described below.
5. Install dependencies:

   ```bash
   flutter pub get
   ```

6. Run static analysis and tests:

   ```bash
   flutter analyze
   flutter test
   ```

7. Run on a connected device/emulator:

   ```bash
   flutter run
   ```

## Environment configuration

Create `.env` in the project root. The client currently reads these values:

```dotenv
SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co
SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
PUBLISHABLE_KEY=YOUR_SUPABASE_PUBLISHABLE_KEY
GOOGLE_WEB_CLIENT_ID=YOUR_GOOGLE_OAUTH_WEB_CLIENT_ID
ONESIGNAL_APP_ID=YOUR_ONESIGNAL_APP_ID
```

Notes:
- `SUPABASE_ANON_KEY` / publishable key are client-side keys and must still be protected by correct RLS policies. Do not put the Supabase `service_role` key in `.env` or the mobile app.
- Keep `.env` out of Git and public ZIPs. `.env.example` contains placeholders only.
- Google OAuth requires matching provider configuration in Supabase and the relevant Android OAuth/client configuration.
- `ONESIGNAL_APP_ID` is the public OneSignal application ID, not the REST API key.
- The current repository loads `.env` as an asset; rebuild/restart the app after changing it.

## Supabase setup

1. Create a Supabase project and note the project URL and client key.
2. In the SQL Editor, review and apply `supabase_schema.sql` to create the application tables and policies. Review the file first and back up an existing database before applying it to a project with data.
3. Apply `supabase/migrations/20261013_phase3_call_security.sql` if it has not already been applied. Migrations should be applied once and tracked in your own deployment history.
4. Review `supabase/notification_push_setup.sql` and apply the relevant setup for your environment.
5. Configure Auth providers (email/password and any social provider you actually use) in Supabase. Set the correct redirect URLs and OAuth credentials for your app.
6. Create/configure the Storage buckets referenced by the code, including avatar/profile images, booking photos, and mechanic verification documents as applicable. Verify their policies in the dashboard and SQL files.
7. Enable Realtime/replication for tables whose changes are consumed by realtime streams. Inspect the providers/repositories before enabling tables; common candidates include bookings, offers, chat messages, booking locations, notifications, and call sessions.
8. Verify RLS with at least two separate test accounts: one customer and one mechanic. Do not use broad public policies in production without a deliberate security review.

The schema file is the source of truth for table definitions and many policies. Do not assume a table or column exists based only on this README; inspect the SQL and current Supabase schema before changing code.

## Edge Functions and secrets

The repository includes these Supabase Edge Functions:

| Function | Purpose | Server-side configuration used |
|---|---|---|
| `compute-route` | Compute route information for map/tracking | `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GOOGLE_ROUTES_API_KEY` (verify current implementation) |
| `livekit-start-call` | Validate/start a call session and initiate related call workflow | `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `LIVEKIT_URL`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`, and notification webhook secret as used by code |
| `livekit-token` | Issue a participant token for a call | `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `LIVEKIT_URL`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET` |
| `livekit-update-call` | Update call lifecycle state | Supabase server credentials and `MECHX_NOTIFICATION_WEBHOOK_SECRET` where required by implementation |
| `send-push-notification` | Deliver OneSignal push notification | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `ONESIGNAL_APP_ID`, `ONESIGNAL_REST_API_KEY`, and any configured webhook secret |

Set secrets in the Supabase project using the Supabase CLI or dashboard; never commit them. Example (replace values locally; do not paste real secrets into chat or Git):

```bash
supabase secrets set \
  LIVEKIT_URL="wss://YOUR_LIVEKIT_HOST" \
  LIVEKIT_API_KEY="YOUR_LIVEKIT_API_KEY" \
  LIVEKIT_API_SECRET="YOUR_LIVEKIT_API_SECRET" \
  GOOGLE_ROUTES_API_KEY="YOUR_GOOGLE_ROUTES_API_KEY" \
  ONESIGNAL_APP_ID="YOUR_ONESIGNAL_APP_ID" \
  ONESIGNAL_REST_API_KEY="YOUR_ONESIGNAL_REST_API_KEY" \
  SUPABASE_SERVICE_ROLE_KEY="YOUR_SERVICE_ROLE_KEY"
```

Also set any additional variables required by the current function source. Deploy functions after configuration:

```bash
supabase functions deploy compute-route
supabase functions deploy livekit-start-call
supabase functions deploy livekit-token
supabase functions deploy livekit-update-call
supabase functions deploy send-push-notification
```

Use the correct Supabase project link/CLI login for your own project. Never publish service-role keys, LiveKit secrets, OneSignal REST API keys, webhook secrets, or Google server-side API keys.

## Maps and location

- Configure Maps SDK/API access in the Google Cloud project for the platforms you ship.
- Android package/application restrictions and API restrictions must match the app and enabled APIs. Use separate keys where appropriate (mobile Maps SDK key versus server-side Routes API key).
- The route Edge Function should keep server-side route credentials out of the client bundle.
- Grant location permission at runtime and handle denial, approximate location, GPS disabled, and poor connectivity.
- Test route updates with both customer and mechanic moving. Confirm the displayed distance updates, and that distances below 1 km display in meters while longer distances display in kilometers.
- Never treat a straight-line GPS distance as a driving route distance unless the UI explicitly labels it as an estimate/fallback.

## Push notifications

1. Create/configure the OneSignal app and platform credentials.
2. Put the public App ID in local `.env` and configure the server-side REST API key as a Supabase secret.
3. Deploy `send-push-notification` and configure its caller/webhook authorization exactly as implemented in the function and SQL setup.
4. Check `supabase/notification_push_setup.sql` and `supabase/functions/send-push-notification/index.ts` for payload format, Android channel ID, and call-specific notification behavior.
5. Test a fresh install and a returning install, with the app foregrounded, backgrounded, and force-closed. Test notification permission denied and granted.

Android notification channels are persistent once created. If channel sound/importance settings change, a new channel ID or clearing/reinstalling app data may be required to validate the new settings. Do not change channel IDs casually after release because users may have channel preferences saved.

## Internet voice calling

Voice calls use LiveKit for media and Supabase Edge Functions/call-session records for call coordination. Push notifications are used to alert the callee when appropriate; the native Android incoming-call UI and notification behavior also depend on Android permissions, notification channels, manifest configuration, and OS/vendor restrictions.

Before release, test:
- Customer calls mechanic and mechanic calls customer where allowed.
- Caller/callee identity and booking relationship are validated server-side.
- Incoming call when app is foregrounded, backgrounded, and force-closed.
- Accept, reject, caller cancellation, remote hang-up, and timeout/no-answer.
- Ringtone starts/stops correctly and does not continue after rejection/end.
- A call cannot be answered after it has been ended/cancelled.
- Poor/unstable internet pauses or clearly indicates connection state and timer behavior.
- Duplicate push events do not create duplicate call screens or sessions.
- Both devices disconnect cleanly and call history reflects the final state.
- LiveKit tokens are short-lived and generated server-side; secrets never ship in Flutter code.

Native call behavior varies by Android version and device manufacturer. Passing a Flutter unit test alone is not sufficient evidence for full-screen incoming calls.

## Database and realtime

Main tables defined in `supabase_schema.sql` include profiles, vehicles, services, bookings, offers, chat messages, booking locations, reviews, notifications, support conversations/messages, and call sessions. Check the schema for exact columns, constraints, relationships, and policies.

- Realtime subscriptions should be filtered to the signed-in user and relevant booking whenever possible.
- Treat booking status transitions as state-machine changes; keep UI conditions consistent with persisted server/database state.
- Never trust client-provided role, mechanic verification, price, or call participant identifiers without server-side checks.
- Use SQL migrations for changes to production schema. Avoid manually editing production tables without recording the migration.

## Run, analyze, and build

```bash
# Install dependencies
flutter pub get

# Static analysis
flutter analyze

# Automated tests
flutter test

# Run on a connected device
flutter run

# Android APK (single APK)
flutter build apk --release

# Android APKs split by ABI
flutter build apk --release --split-per-abi

# Android App Bundle for Play Console
flutter build appbundle --release
```

If the project uses a local Android SDK/JDK path, verify it is machine-specific and do not commit personal `local.properties` settings. Resolve analysis/build errors before distributing a release. Keep the current dependency lockfile unless you intentionally plan and test a dependency update.

## Manual QA checklist

### Authentication and profile
- [ ] Sign up, log in, log out, and restore session after restart.
- [ ] Customer and mechanic accounts route to the correct home screen.
- [ ] Invalid credentials and network errors show understandable messages.
- [ ] Profile/avatar upload and access controls work as expected.

### Customer booking
- [ ] Add/edit/delete vehicle; vehicle list belongs only to the signed-in customer.
- [ ] Search/browse service and open service details.
- [ ] Select service → select vehicle → describe issue → set location → submit request.
- [ ] Attach and view booking photos if used.
- [ ] Pending booking reopens the same offers list after navigation/app restart.
- [ ] Cancel booking and confirm state updates on both sides.
- [ ] Accept an offer and confirm map/chat/call/payment actions match the booking state.

### Mechanic flow
- [ ] New request appears without app restart.
- [ ] Submit offer and confirm customer receives it.
- [ ] Accepted job appears in mechanic bookings and job states progress correctly.
- [ ] Completion, payment state, earnings, and rating update without requiring restart.

### Map and realtime
- [ ] Customer and mechanic locations update on the other device.
- [ ] Route line refreshes when either endpoint changes.
- [ ] Distance refreshes; under 1 km uses meters, 1 km or more uses kilometers.
- [ ] GPS denied/offline/route API failure produces a safe fallback, not a crash.

### Chat, notifications, and calls
- [ ] Chat messages update in realtime and remain scoped to booking participants.
- [ ] Booking and call push notifications arrive on fresh install and after app restart.
- [ ] Incoming call UI, ringtone, accept/reject/end and call history work on two physical devices.
- [ ] Test foreground, background, force-closed, network loss, duplicate push, and permission-denied states.

### Release readiness
- [ ] `flutter analyze` passes or remaining warnings are understood and documented.
- [ ] `flutter test` passes.
- [ ] Release APK/App Bundle builds successfully.
- [ ] Production keys are not in Git, APK assets, logs, or documentation.
- [ ] Supabase RLS/storage policies are reviewed with separate customer/mechanic test accounts.

## Security notes

- Never commit `.env`, Firebase private credentials, service-role keys, LiveKit API secrets, OneSignal REST API keys, or webhook secrets.
- Keep `.env.example` placeholder-only.
- RLS is mandatory for user-owned records. Test policies as different authenticated users, not only as an administrator.
- Edge Functions must authenticate callers and validate booking membership, roles, call status, and payloads before privileged operations.
- Avoid logging access tokens, private keys, personal phone numbers, or unnecessary location history.
- Restrict Google API keys by API and application/server identity. Server keys must not be embedded in Flutter assets.
- Review uploaded mechanic verification documents and booking images for appropriate access restrictions before production.
- The included SQL should be reviewed against the intended production security model before applying it to a live database.

## Troubleshooting

**`.env` values appear null** — confirm `.env` is at the Flutter project root, keys match the names above, it is declared under Flutter assets, and the app was rebuilt after changes.

**Supabase request returns 401/403** — verify the current user session, RLS policies, row ownership, bucket policies, and Edge Function secrets. Do not fix access errors by making all tables publicly writable.

**No realtime update** — verify Realtime is enabled for the table, filters use correct IDs, subscriptions are disposed/recreated appropriately, and both devices use different test accounts.

**Google map blank or routes fail** — check API enablement, key restrictions, billing, platform manifest configuration, device location permission, and the Edge Function logs.

**Push does not arrive** — check OneSignal App ID, platform setup, notification permission, device subscription/token, Edge Function logs, REST API secret, Android channel ID, and payload target.

**Incoming call screen/ringtone does not appear** — check notification permission, Android channel settings, manifest/intent configuration, full-screen intent behavior for the OS version, OneSignal payload/channel, LiveKit token function logs, and call-session state. Reinstall or use a new channel ID only when intentionally testing changed channel settings.

**Build fails on another computer** — run `flutter doctor -v`, check Flutter/Dart compatibility, Android SDK/JDK/Gradle/AGP compatibility, and machine-local `android/local.properties`. Do not randomly upgrade Gradle or plugin versions as a first response.

## Versioning and release

`pubspec.yaml` uses Flutter's `version: MAJOR.MINOR.PATCH+BUILD` format. Example:

```yaml
version: 1.0.1+2
```

- Increment patch for backward-compatible fixes, minor for new backward-compatible features, and major for breaking changes.
- Increase the build number for every distributed Android/iOS build.
- Tag source releases in Git, for example `v1.0.1`, and keep release notes with the tag.
- Build and test the release artifact before sharing it; never distribute debug builds as production releases.

## Known deployment-specific work

This repository requires project-specific setup in Supabase, Google Cloud, OneSignal, and LiveKit. OAuth credentials, API keys, notification permissions, Android channel behavior, and physical-device call behavior cannot be validated from source files alone. Complete the setup and QA checklists above before publishing.

## License and attribution

No open-source license is declared in this repository. Add a `LICENSE` file before publicly redistributing the project. Review the licenses/terms for all third-party packages and services used.
