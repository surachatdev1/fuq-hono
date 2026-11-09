# Responsive Flutter Web on Vercel

The Flutter UI now has conditional camera, reminders and HTTP implementations for Web. Android/iOS keep their existing platform implementations. The phone bottom navigation changes to a rail at 840 px and a sidebar at 1200 px. Wide attendance screens show status and next action side by side. Login keeps a readable form beside the brand panel.

## Build and verification

Use Flutter 3.35.7 (commit adc901062556672b4138e18a4dc62a4be8f4b3c2), Node 24, `npm ci`, `npm test`, `flutter pub get`, `flutter analyze`, `flutter test`, then `bash scripts/build-web.sh`. Set `CI=true FLUTTER_SUPPRESS_ANALYTICS=true` before invoking Flutter to avoid cloud metadata autodetection and analytics. The build script does this itself.

Vercel: framework Other, install `npm ci`, build `bash scripts/build-web.sh`, output `build/web`, functions in `api/[route].js`, Singapore region. The script downloads the pinned Flutter Git tag if it is absent, checks its exact commit, builds JavaScript (not Wasm), bundles local MediaPipe 1.2.2 WASM/model and local CanvasKit. No camera or face image is sent to Google for the local blink challenge. The HONO-configured identity and anti-spoof providers still receive the fresh capture as in the mobile flow.

## Required Vercel environment configuration

Configure production and preview separately through the Vercel dashboard. Do not paste secrets into chat, GitHub, browser localStorage or files committed to the repository.

- `SESSION_SECRET`: a fresh 32-byte cryptographically random key encoded as 64 hexadecimal characters. Generate it on a trusted machine (for example `openssl rand -hex 32`). Store as a sensitive/encrypted variable. This protects the HttpOnly Secure SameSite=Strict session cookie. No password is retained.
Redis, Supabase, and other external state stores are not required. Existing Redis integration variables may remain configured but this implementation does not read or call them.

Redeploy after configuration. Login fails closed before contacting HONO if SESSION_SECRET is missing. No shared secret is hardcoded as a fallback. Set SESSION_SECRET separately for Production and Preview when enabling real login there.

## Request boundary

Only explicit same-origin routes are allowed. The browser never receives HONO session/API keys or enrollment-provider keys. Employee identity is read from the sealed server session, never from attendance request fields. The calendar uses processed `startTime`/`endTime`; raw history remains separate. Changing dates clears old rows using the existing epoch guards.

A fresh, single-face blink capture precedes HONO enrollment verification. The configured spoof check remains enforced. The server issues an HMAC-SHA256 proof bound to the account/session, JPEG hash, Bangkok date and current history fingerprint, with a random ID and a 60-second expiry. A domain-separated signature uses SESSION_SECRET; a cookie cannot be reused as a face proof. The server rechecks current history/state, generates PNG from the verified JPEG, and submits once. No automatic write retry or upload-file substitution.

UI busy guards block repeated clicks. Per-process maps track used proof IDs until expiry and account write locks for up to 90 seconds. Confirmed outcomes release the account lock; uncertain outcomes retain it and the UI requires explicit history review. These maps are bounded and best-effort: cold starts and different serverless instances do not share them. Fresh history catches visible intervening punches but cannot guarantee cross-instance atomic deduplication or immediate upstream consistency. The user explicitly selected this simpler, no-database tradeoff.

Checkout before 18:00 Bangkok wall time shows a confirmation dialog before opening the camera. Cancel closes the dialog without capturing or writing; confirm continues to the normal fresh scan and automatic submission on match. The 18:00 threshold matches the current reminder policy; HONO's raw outTime is not treated as a shift-end schedule. This is a UI warning, not a company approval or a server-side attendance restriction. Face images stay in request memory and are not persisted.

## Browser limits and acceptance

HTTPS and explicit camera permission are required. Safari/Chrome may suspend hidden tabs. Web reminders use the existing local attendance/calendar cache and an in-page prompt at 08:20, 08:30, 08:50 and 18:00 Bangkok time while the page remains open. They are not closed-browser or exact OS alarms. The UI states this limitation. Sound is generated locally and browsers may require a user interaction to allow it. No API calls happen in the reminder timer.

The manifest supports adding the app to the home screen; no offline HR writes are queued. No service worker caches session/API/biometric data. The web build replaces public protocol material with a harmless local constructor stub; real protocol material remains bundled only in the Node function.

Real account login and real attendance writes must be tested by the account holder after environment configuration. Development verification uses fixtures and does not create HR attendance entries.

## Verification record — 2026-11-09

The initial production deployment reached READY. The deployed login, demo dashboard and history navigation were inspected in Chrome; the login endpoint returned 503 with the expected missing-session-configuration message and did not attempt a real account login. Seven fixture-based Node gateway tests passed, including an uncertain writer result, one-use proof replay rejection and swapped-image rejection. Flutter analysis has no issues. Responsive widget checks cover 320, 390, 768, 1024 and 1440 px. The compact app-bar logo was constrained to avoid overflow at 320 px. Alarm screenshot fixtures use a fixed display clock so minute changes cannot invalidate the baseline. No real HR punches were submitted.

The old Vercel project was identified as `rakadee-web` (`prj_9H2mtXoakpLhnpUEuHCut8iTaaRN`). The Vercel deletion tool returned requires_user_action / mutationExecuted=false. It remains in place until the account holder confirms deletion in the Vercel dashboard.

## No-Redis update — 2026-11-09

Removed all Redis calls/configuration requirements from the gateway. Verification covers signed-proof tampering/expiry, same-process duplicate/uncertain-write protection, swapped-image rejection, 18:00 warning boundaries and both dialog actions. Earlier deployment records above describe the historical baseline. Actual live face capture/attendance writes still require account-owner UAT.
