# Web Login diagnostics (Vercel, 2026-11-10)

## Scope
- Public web: https://fuq-hono-rakadee.vercel.app/
- Vercel project: `rakadee/fuq-hono`, environment: **Production**
- Source: `api/[route].js`, `server/hono.js`, `server/session.js`, `lib/data/hono_web.dart`

## What is logged
Each successful web login emits one JSON `nwl.request` event; errors from every API route emit an event. Fields: requestId (12 random hexadecimal characters), route, stage, HTTP status, safe error code, elapsedMs, platform class (ios/android/desktop/unknown), and upstream HTTP status (integer only, when applicable).

**Never log:** employee number, username, email, company code, password, access token, cookies, Set-Cookie, Session Secret, raw User-Agent, IP address, HONO request URLs/query strings, upstream response body, face images, or proofs.

Errors return the same requestId in the `X-Request-ID` header and JSON `requestId`. The Flutter Web client displays this ID when the backend returns an error. Operators can correlate the user's screenshot and approximate time with the matching Vercel log line, without the user sharing credentials.

## Login stage taxonomy
| Stage | Meaning |
| --- | --- |
| validation | Request validation / session configuration |
| company_lookup | Initial HONO company discovery |
| company_policy | Company SSO and domain policy |
| api_keys | HONO dynamic keys lookup |
| credential_auth | Tenant credential authentication request |
| account_policy | MFA, account action required, or session fields |
| complete | Login succeeded and session cookie was issued |

## Expected codes
- `auth_rejected` (HTTP 401): HONO explicitly returned `result: false`. This does not establish whether the password, account state or access rights caused the rejection.
- `sso_required`, `mfa_required`, `account_action_required` (HTTP 403): User must use the official HONO flow or satisfy account policy.
- `session_cookie_missing` (HTTP 401, usually `history` or `state` route): No first-party web cookie arrived after login. Investigate Safari private browsing, in-app browsers, settings, and cross-domain navigation.
- `session_invalid` (HTTP 401): Cookie existed but was unreadable or expired.
- `auth_session_incomplete` (HTTP 502): Upstream reported a success but did not supply required session fields.
- `upstream_rejected` (HTTP 502): A non-credential HONO endpoint rejected an operation.
- `upstream_http` (HTTP 502, with numeric upstreamStatus): HONO responded with non-200.
- `upstream_timeout` (HTTP 504): HONO did not respond before the timeout.
- `upstream_network`, `upstream_json`, `upstream_stream` (HTTP 502): Transport or response-format problem.

## How to investigate a reported failure
1. Ask for the **request ID** from the displayed error and the approximate Bangkok time. Do not ask for the employee password, session cookie, token, or screenshot of secrets.
2. Open Vercel Runtime Logs for Production and filter `nwl.request`, or search the specific requestId. Use the plan's retention window (Hobby often provides only a short recent window).
3. Read `stage`, `code`, `status`, and optionally `upstreamStatus`. Never infer invalid credentials solely from an HTTP 502.
4. If the Login reports 200 but later `history` reports `session_cookie_missing`, verify cookies and whether the user stayed on the same domain.
5. For `auth_rejected`, have the user validate that the same account can authenticate in the official HONO app. Account-specific access cannot be proven without an authorized account-owner test.
6. Avoid making real attendance writes during diagnostics. Health tests should be read-only or mock-based.

The Node.js `url.parse()` deprecation warning (DEP0169) is a dependency/runtime warning, not evidence of a failed HONO authentication. Existing Vercel telemetry alone cannot determine why a particular user's Login returned 502 before these diagnostic events were deployed.
