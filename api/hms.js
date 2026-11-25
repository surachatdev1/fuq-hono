import { createHash, createHmac, randomBytes, timingSafeEqual } from 'node:crypto';
import { hmsPage } from '../server/hms-page.js';

const portal = 'https://hrs.humansoft.co.th/auth/login';
const issuer = 'https://auth.humansoft.co.th/oauth2/v1';
const flowCookie = '__Host-fuq-hms-flow';
const resultCookie = '__Host-fuq-hms-result';

function cookie(name, value, age) {
  return name + '=' + value + '; Path=/; Secure; HttpOnly; SameSite=Lax; Max-Age=' + age;
}

function readCookie(req, name) {
  return (req.headers.cookie || '').split(/;\s*/).find(part => part.startsWith(name + '='))?.slice(name.length + 1);
}

function sign(value, name, secret) {
  return createHmac('sha256', secret).update(name + '.' + value).digest('base64url');
}

function ticket(name, value, secret) {
  const data = Buffer.from(JSON.stringify({ ...value, expires: Date.now() + 300000 })).toString('base64url');
  return data + '.' + sign(data, name, secret);
}

function unpack(req, name, secret) {
  const raw = readCookie(req, name);
  if (!raw || raw.length > 1200) return null;
  const [value, mac] = raw.split('.');
  const signature = Buffer.from(sign(value, name, secret));
  const supplied = Buffer.from(mac || '');
  if (supplied.length !== signature.length || !timingSafeEqual(supplied, signature)) return null;
  try {
    const data = JSON.parse(Buffer.from(value, 'base64url').toString('utf8'));
    return data.expires > Date.now() ? data : null;
  } catch { return null; }
}

function clientFor(req, env) {
  const url = env.HMS_OAUTH_CALLBACK_URL ||
    (env.VERCEL_ENV === 'production' ? 'https://fuq-hono.vercel.app/api/hms' : '');
  const secret = env.SESSION_SECRET;
  if (!env.HMS_OAUTH_CLIENT_ID || !/^[a-fA-F0-9]{64}$/.test(secret || '')) return null;
  try {
    const callback = new URL(url);
    if (callback.protocol !== 'https:' || callback.pathname !== '/api/hms' ||
        callback.search || callback.hash || callback.username || callback.password ||
        callback.host !== req.headers.host) return null;
  } catch { return null; }
  return { id: env.HMS_OAUTH_CLIENT_ID, url, secret };
}

function redirect(res, url) {
  res.statusCode = 303;
  res.setHeader('Location', url);
  res.end();
}

async function employeeConfirmed(client, flow, code, request) {
  const options = { redirect: 'error', signal: AbortSignal.timeout(7000) };
  const response = await request(issuer + '/token', {
    ...options, method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ grant_type: 'authorization_code', code, client_id: client.id,
      redirect_uri: client.url, code_verifier: flow.verifier })
  });
  if (!response.ok) return false;
  const tokens = await response.json();
  if (typeof tokens.access_token !== 'string' || !tokens.access_token ||
      tokens.token_type?.toLowerCase() !== 'bearer') return false;
  const info = await request(issuer + '/userinfo', {
    ...options, headers: { Authorization: 'Bearer ' + tokens.access_token }
  });
  if (!info.ok) return false;
  const profile = await info.json();
  return typeof profile.sub === 'string' && profile.sub.length > 0;
}

export function createHmsHandler(env, request) {
  return async function hms(req, res) {
    res.setHeader('Cache-Control', 'private, no-store');
    res.setHeader('Referrer-Policy', 'no-referrer');
    res.setHeader('X-Robots-Tag', 'noindex, nofollow');
    res.setHeader('Content-Security-Policy', "default-src 'none'; style-src 'self'; font-src 'self'; img-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'");
    if (!['GET', 'HEAD'].includes(req.method)) {
      res.statusCode = 405;
      res.setHeader('Allow', 'GET, HEAD');
      return res.end();
    }
    const requested = new URL(req.url, 'http://localhost');
    const query = requested.searchParams;
    const client = clientFor(req, env);
    if (query.has('code') || query.has('error') || query.has('state')) {
      if (req.method === 'HEAD') { res.statusCode = 405; return res.end(); }
      if (!client) return redirect(res, '/hms');
      const flow = unpack(req, flowCookie, client.secret);
      let outcome = 'expired';
      if (flow && flow.state === query.get('state')) {
        outcome = 'failed';
        const code = query.get('code');
        if (query.get('error') === 'access_denied') outcome = 'cancelled';
        else if (!query.has('error') && code && code.length <= 4096) {
          try {
            if (await employeeConfirmed(client, flow, code, request)) outcome = 'verified';
          } catch { /* Show an inconclusive result if the provider is unreachable. */ }
        }
      }
      res.setHeader('Set-Cookie', [cookie(flowCookie, '', 0),
        cookie(resultCookie, ticket(resultCookie, { outcome }, client.secret), 300)]);
      return redirect(res, '/hms');
    }
    if (query.get('start') === '1') {
      if (!client) return redirect(res, portal);
      if (req.method === 'HEAD') { res.statusCode = 405; return res.end(); }
      const state = randomBytes(32).toString('base64url');
      const verifier = randomBytes(48).toString('base64url');
      const params = new URLSearchParams({ client_id: client.id, redirect_uri: client.url,
        scope: 'openid', response_type: 'code', user_type: 'hrs', instance_server_code: 'PSDGROUP',
        state, code_challenge: createHash('sha256').update(verifier).digest('base64url'), code_challenge_method: 'S256' });
      res.setHeader('Set-Cookie', [cookie(flowCookie, ticket(flowCookie, { state, verifier }, client.secret), 300),
        cookie(resultCookie, '', 0)]);
      return redirect(res, issuer + '/authorize?' + params);
    }
    const outcome = client && unpack(req, resultCookie, client.secret)?.outcome;
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    const attendance = requested.pathname.replace(/\/$/, '') === '/hms/attendance' || query.get('view') === 'attendance';
    return res.end(req.method === 'HEAD' ? undefined : hmsPage({ client: Boolean(client), outcome, portal, attendance }));
  };
}

export default createHmsHandler(process.env, (...args) => fetch(...args));
