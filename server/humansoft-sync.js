import {createHash} from 'node:crypto';
import {Failure} from './hono.js';

const digest = value => createHash('sha256').update(value).digest('hex');
const months = 'jan feb mar apr may jun jul aug sep oct nov dec'.split(' ');
const pad = number => String(number).padStart(2, '0');

// Same supported date/clock formats as the HONO history screen, in Bangkok time.
export function sourceDateTime(date, raw) {
  const text = String(raw ?? '').trim();
  if (/^\d{4}-\d\d-\d\dT\d\d:\d\d(?::\d\d(?:\.\d+)?)?(?:Z|[+-]\d\d:?\d\d)$/i.test(text)) {
    const ms = Date.parse(text);
    if (!Number.isFinite(ms)) return null;
    const local = new Date(ms + 7 * 3600000).toISOString().slice(0, 19).replace('T', ' ');
    return local.startsWith(date + ' ') ? local : null;
  }
  const legacy = /^(\d{1,2})-([a-z]{3})-(\d{4})-+\s*(\d{1,2}):(\d\d)(?::(\d\d))?\s*(am|pm)$/i.exec(text);
  let hour, minute, second;
  if (legacy) {
    const [, day, month, year, h, m, s = '00', ampm] = legacy;
    if (year + '-' + pad(months.indexOf(month.toLowerCase()) + 1) + '-' + pad(day) !== date || +h < 1 || +h > 12) return null;
    hour = +h % 12 + (ampm.toLowerCase() === 'pm' ? 12 : 0); minute = +m; second = +s;
  } else {
    const parts = /^(?:(\d{4}-\d\d-\d\d)[ T])?(\d{1,2}):(\d\d)(?::(\d\d))?$/.exec(text);
    if (!parts || (parts[1] && parts[1] !== date)) return null;
    hour = +parts[2]; minute = +parts[3]; second = +(parts[4] ?? 0);
  }
  if (hour > 23 || minute > 59 || second > 59) return null;
  return date + ' ' + [hour, minute, second].map(pad).join(':');
}

// Compare-and-set the entire serialized entry so two function instances cannot
// both own the POST. A surviving 'sending' entry may only be checked by GET.
const casScript = `
local old = redis.call('HGET', KEYS[1], ARGV[1])
if (old or '') ~= ARGV[2] then return 0 end
if ARGV[4] ~= '' and redis.call('HSETNX', KEYS[1], ARGV[4], ARGV[1]) == 0 then return 0 end
if ARGV[3] == '' then redis.call('HDEL', KEYS[1], ARGV[1])
else redis.call('HSET', KEYS[1], ARGV[1], ARGV[3]) end
redis.call('EXPIRE', KEYS[1], 3888000)
return 1`;

export function syncFor(session, date, env = process.env) {
  const mode = env.HUMANSOFT_IMPORT_MODE;
  if (!mode || mode === 'off' || session.company.toLowerCase() !== 'psd') return null;
  const badConfig = () => new Failure('การตั้งค่าเชื่อมต่อ HumanSoft ยังไม่ครบ กรุณาติดต่อผู้ดูแล', 503, 'sync_config');
  if (!['uat','production'].includes(mode) || (mode === 'production' && env.VERCEL_ENV !== 'production')) throw badConfig();
  let mapping;
  try { mapping = JSON.parse(env.HUMANSOFT_EMPLOYEE_MAP); } catch { throw badConfig(); }
  if (!mapping || typeof mapping !== 'object' || Array.isArray(mapping)) throw badConfig();
  const employees = Object.values(mapping);
  if (employees.some(e => typeof e !== 'string' || !e.trim()) || new Set(employees).size !== employees.length) throw badConfig();
  if (!Object.hasOwn(mapping, session.employee)) return null;
  const employee = mapping[session.employee];
  const url = env.UPSTASH_REDIS_REST_URL ?? env.KV_REST_API_URL;
  const bearer = env.UPSTASH_REDIS_REST_TOKEN ?? env.KV_REST_API_TOKEN;
  if (!url?.startsWith('https://') || !bearer || !env.HUMANSOFT_IMPORT_KEY) throw badConfig();
  const root = 'https://openapi.humansoft.co.th' + (mode === 'uat' ? '/uat' : '') + '/api/v1/open-apis';
  const key = 'nwl:hs:v1:' + mode + ':' + date + ':' + digest(JSON.stringify([session.company, session.employee, employee]));
  async function redis(command) {
    const res = await fetch(url, {method:'POST', redirect:'error', signal:AbortSignal.timeout(2500),
      headers:{Authorization:'Bearer '+bearer, 'Content-Type':'application/json'}, body:JSON.stringify(command)});
    if (!res.ok) throw Error('delivery store unavailable');
    const data = await res.json();
    if (data.error || !Object.hasOwn(data,'result')) throw Error('delivery store rejected command');
    return data.result;
  }
  async function change(id, before, after, claim = '') {
    const old = before === null ? '' : JSON.stringify(before);
    const next = after === null ? '' : JSON.stringify(after);
    return await redis(['EVAL',casScript,1,key,id,old,next,claim]) === 1;
  }
  async function provider(path, init = {}) {
    return fetch(root + path, {...init, redirect:'error', signal:AbortSignal.timeout(4500),
      headers:{'Ocp-Apim-Subscription-Key':env.HUMANSOFT_IMPORT_KEY,'Content-Type':'application/json'}});
  }
  function timesFor(rows, punch) {
    return rows.filter(row => row.flag === punch).map(row => sourceDateTime(date,row.punch_time) ?? String(row.punch_time)).sort();
  }
  async function reserve(rows,punch) {
    const before = timesFor(rows,punch);
    const id = digest(JSON.stringify([punch,before]));
    const entry = {state:'reserved',punch,before,started:Date.now()};
    let acquired;
    try { acquired = await change(id,null,entry); }
    catch { throw new Failure('ตรวจรายการซ้ำไม่ได้ กรุณาลองใหม่',503,'sync_store'); }
    if (!acquired) throw new Failure('พบการส่งรายการนี้แล้ว กรุณาตรวจประวัติก่อนลงเวลาอีกครั้ง',409,'sync_duplicate');
    return {id,entry};
  }
  function candidate(entry,rows) {
    const times = timesFor(rows,entry.punch);
    for (const existing of entry.before) {
      const index = times.indexOf(existing);
      if (index < 0) return null;
      times.splice(index,1);
    }
    // Never attribute another app's later punch or an ambiguous change to FUQ.
    const nearby = times.filter(time => {
      if (!/^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d$/.test(time)) return false;
      const delta = Date.parse(time.replace(' ','T') + '+07:00') - entry.started;
      return delta >= -60_000 && delta <= 90_000;
    });
    return nearby.length === 1 && times.filter(t => t === nearby[0]).length === 1 &&
      !entry.before.includes(nearby[0]) ? nearby[0] : null;
  }
  const direction = punch => punch === 'I' ? 'IN' : 'OUT';
  async function importPunch(entry) {
    const payload = {import_data:[{status:'ADD',employee_code:employee,date,datetime:entry.time,time_attendance_type:direction(entry.punch)}]};
    try {
      const res = await provider('/time-attendance/import',{method:'POST',body:JSON.stringify(payload)});
      if ([400,401,403,422].includes(res.status)) return 'rejected';
      if (!res.ok) return 'unknown';
      const reply = await res.json();
      const invalid = reply?.payload?.invalid_items;
      if (Array.isArray(invalid) && invalid.length) return 'rejected';
      if (Number(reply.code) === 200 && reply.message === 'successfully en-queued' &&
          (Array.isArray(invalid) || (Array.isArray(reply.payload) && reply.payload.length === 0))) return 'queued';
      return 'unknown';
    } catch { return 'unknown'; }
  }
  async function recorded() {
    const query = new URLSearchParams({path_action:'search_time_attendance',employee_code:employee,
      date_from:date,date_to:date,_PAGE:'1',_NUMBER_PER_PAGE:'100'});
    const res = await provider('/salary/get-data-filter?' + query);
    if (!res.ok) throw Error('history unavailable');
    const data = await res.json();
    if (Number(data.code) !== 200 || !Array.isArray(data.payload)) throw Error('invalid destination history');
    if (Number(data._PAGINATION?._TOTAL_RECORDS ?? data.payload.length) > data.payload.length ||
        (!data._PAGINATION && data.payload.length >= 100)) throw Error('incomplete destination history');
    return data.payload;
  }
  function matches(rows,entry) {
    return rows.some(row => row.employee_code === employee && row.attendance_datetime === entry.time &&
      row.attendance_inout === direction(entry.punch) && row.time_attendance_transac_id);
  }
  async function advance(id,entry,rows,readDestination) {
    if (entry.state === 'waiting') {
      const time = candidate(entry,rows);
      if (!time) return entry;
      const sending = {state:'sending',punch:entry.punch,time};
      let existing;
      try { existing = await readDestination(); } catch { return entry; }
      if (matches(existing,sending)) {
        const confirmed = {...sending,state:'recorded'};
        return await change(id,entry,confirmed) ? confirmed : entry;
      }
      // A stamp at this instant with unresolved direction must be reviewed
      // before creating a potentially duplicate payroll record.
      if (existing.some(row => row.employee_code === employee && row.attendance_datetime === time &&
          !['IN','OUT'].includes(row.attendance_inout))) {
        const review = {...sending,state:'review'};
        return await change(id,entry,review) ? review : entry;
      }
      if (!await change(id,entry,sending,'claim:'+entry.punch+':'+time)) return entry;
      const next = {...sending,state:await importPunch(sending)};
      await change(id,sending,next);
      return next;
    }
    if (['queued','sending','unknown'].includes(entry.state) && matches(await readDestination(),entry)) {
      const confirmed = {...entry,state:'recorded'};
      await change(id,entry,confirmed);
      return confirmed;
    }
    return entry;
  }
  return {
    reserve,
    async cancel(ticket) { await change(ticket.id,ticket.entry,null); },
    async confirmed(ticket,readHonoHistory) {
      const waiting = {...ticket.entry,state:'waiting'};
      try {
        if (!await change(ticket.id,ticket.entry,waiting)) return 'review';
      } catch { return 'review'; }
      try {
        const rows = (await readHonoHistory()).data;
        return (await advance(ticket.id,waiting,rows,recorded)).state;
      } catch { return 'waiting'; }
    },
    async reconcile(rows) {
      // Only recorded intents for this employee/day can trigger delivery.
      const pairs = await redis(['HGETALL',key]);
      let destination;
      const read = () => destination ??= recorded();
      const annotations = new Map();
      for (let i=0;i<pairs.length;i+=2) {
        if (pairs[i].startsWith('claim:')) continue;
        let entry = JSON.parse(pairs[i+1]);
        if (entry.state === 'reserved') continue; // HONO acknowledgement is unknown.
        try { entry = await advance(pairs[i],entry,rows,read); } catch { /* retain last known state */ }
        if (entry.time) annotations.set(entry.punch+'|'+entry.time,entry.state);
      }
      return rows.map(row => {
        const state = annotations.get(row.flag+'|'+sourceDateTime(date,row.punch_time));
        return state ? {...row,humanSoft:state} : row;
      });
    }
  };
}
