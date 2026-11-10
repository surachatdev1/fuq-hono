# Vercel Node.js 24 DEP0169 diagnosis

## Root cause (verified on Preview 2026-11-10)

The `DEP0169` warning appeared on the `fuq-hono` Node.js 24 Vercel Function even when the handler returned a simple HTTP 405 without contacting HONO. A temporary `process.on('warning')` listener captured this stack:

```
at urlParse (node:url:136:13)
at /opt/rust/nodejs.js:2:10345
at IncomingMessage.get (/opt/rust/nodejs.js:2:12358)
at handler (file:///var/task/api/%5Broute%5D.js:20:24)
```

The application referenced Vercel's `req.query` convenience getter to discover the dynamic route. That getter lazily calls the legacy `url.parse()` implementation in Vercel's internal `/opt/rust/nodejs.js` Node adapter. **The project's own modules do not directly use `url.parse()`.**

## Fix

Read `req.url` directly, parse it with `new URL(raw, 'https://app.invalid')`, match only allowlisted `/api/<route>` path segments, and avoid accessing `req.query` at all. Keep Node.js 24. Do not mute warnings using `NODE_NO_WARNINGS` or `--no-deprecation`. No changes were made to credential handling, session cookies, biometric verification, or attendance writes.

The test suite uses actual request `url` strings instead of mocked `query.route`. A regression test defines a `query` getter that throws and asserts that the HTTP handler still completes successfully without invoking it. It also rejects malformed/encoded/external paths.

## Verification

- GitHub CI: `npm test`, `flutter analyze`, `flutter test`, `flutter build web`
- On the Preview deployment for this fix, send a safe `GET /api/login` (expected HTTP 405 with a safe `nwl.request` event at `route=login`). No credentials or HR writes are required.
- Search Vercel Runtime Logs scoped to the Preview deployment for `DEP0169`. Verify none is emitted for the request; make at least one cold start and another request.
- Remove the temporary warning trace listener before production merge.
- After Production deployment, verify `/api/login` returns 405 to a GET, log event is present, and the production logs no longer produce `DEP0169`.

**Caveat:** Vercel's own runtime may use legacy URLs in other code paths. This fix removes the proven application trigger, not the platform's underlying implementation. A future Vercel runtime upgrade remains the platform-side long-term solution.
