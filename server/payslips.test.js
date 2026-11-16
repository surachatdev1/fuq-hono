import assert from 'node:assert/strict';
import test from 'node:test';
import handler from '../api/[route].js';
import {seal} from './session.js';

const session = {
  id: 'fixture-session',
  exp: Date.now() + 3600000,
  company: 'psd',
  employee: 'employee-with-leading-zeros-0001',
  token: 'fixture-token',
  payrollKey: 'fixture-payroll',
  markKey: 'fixture-attendance',
  base: 'https://psd.hono.ai/sapi/Service/',
  php: '1',
};

const period = '31-10-2026';
const fakePdf = Buffer.from('%PDF-1.7\n% synthetic test file\n%%EOF');
const pdfUrl = 'https://psd.hono.ai/Documents/fixture.pdf';

function mockProvider({group = '0', owner = session.employee, source = 'https://psd.hono.ai'} = {}) {
  const visited = [];
  const fetcher = async (url, options) => {
    const request = new URL(url);
    const action = request.pathname.split('/').at(-1);
    visited.push(action);
    assert.equal(options.redirect, 'error');
    if (request.href === pdfUrl) return new Response(fakePdf);
    if (action === 'checkForAttMethod_v2') {
      const envelope = request.searchParams.get('encryption_key');
      const fields = new URL(Buffer.from(envelope.slice(3, -3), 'base64').toString()).searchParams;
      assert.equal(fields.get('userid'), session.employee);
      assert.equal(fields.get('token'), 'fixture-token');
      return Response.json({result: 'true'});
    }
    const fields = request.searchParams;
    assert.equal(fields.get('comp_code'), 'psd');
    assert.equal(fields.get('api_key'), 'fixture-payroll');
    assert.equal(fields.get('emp_code'),
      ['getEmpSalary', 'getEmpPaySlip'].includes(action) ? 'provider-employee-reference' : session.employee);
    switch (action) {
      case 'getEmpPayrollYear':
        return Response.json({result: 'true', Selected: '2026', finYear: [{FY: '2026'}], paygroupFlag: group});
      case 'getEmpPayrollMonth':
        assert.equal(fields.get('year'), '2026');
        return Response.json({result: true, CURRENT_CODE: period, MONTH: [{MONTHCODE: period, PAYDATE: 'October 2026'}]});
      case 'payrollEncryption':
        assert.equal(fields.get('action'), 'encrypt');
        return Response.json({result: true, data: 'provider-employee-reference'});
      case 'getEmpSalary':
        assert.equal(fields.get('month'), period);
        assert.equal(fields.get('paygroup'), '');
        assert.equal(fields.get('site'), '');
        return new Response(`{"result":"true","emp_code":${JSON.stringify(owner)},"salary":{"GROSSPAY":52000.10,"GROSSDED":"2,000.05","NETPAY":50000.04},"Earning":[{"Payhead":"เงินเดือน","Value":"50,000.00"},{"Payhead":"OT","Value":2000.10}],"Deduction":[{"Payhead":"ภาษี","Value":2000.05}],"Reimbursement":[{"Payhead":"เบิกคืน","Value":"0.00"}],"Arrear":[{"Payhead":"ยอดปรับ","Value":-0.01}],"private_field":"not returned"}`);
      case 'getEmpPaySlip':
        assert.equal(fields.get('month'), period);
        return Response.json({result: true, url: source, path: '/Documents/fixture.pdf'});
      default:
        throw new Error('Unexpected provider request: ' + request.hostname);
    }
  };
  return {visited, fetcher};
}

async function invoke(fields, {input = session} = {}) {
  const origin = 'https://web.example';
  const response = {
    headers: {},
    setHeader(name, value) { this.headers[name] = value; },
    status(statusCode) { this.statusCode = statusCode; return this; },
    json(body) { this.body = body; return this; },
    send(body) { this.body = body; return this; },
  };
  await handler({
    method: 'POST', url: '/api/payslips',
    headers: {
      origin, host: 'web.example',
      'content-type': 'application/json',
      cookie: input ? '__Host-nwl=' + seal(input) : '',
    },
    body: {company: session.company, employee: session.employee, ...fields},
  }, response);
  return response;
}

async function testWithProvider(testContext, options = {}) {
  const provider = mockProvider(options);
  testContext.mock.method(globalThis, 'fetch', provider.fetcher);
  testContext.mock.method(console, 'info', () => {});
  testContext.mock.method(console, 'warn', () => {});
  process.env.SESSION_SECRET = 'ab'.repeat(32); // Test-only key.
  return provider;
}

test('payslips use employee-owned periods and preserve source totals and line values', async t => {
  const {visited} = await testWithProvider(t);
  const response = await invoke({action: 'detail', year: '2026', period});
  assert.equal(response.statusCode, 200);
  assert.match(response.headers['Cache-Control'], /no-store/);
  assert.deepEqual(response.body, {
    period: {id: period, label: 'October 2026'},
    summary: {gross: '52000.10', deductions: '2,000.05', net: '50000.04'},
    earnings: [{label: 'เงินเดือน', amount: '50,000.00'}, {label: 'OT', amount: '2000.10'}],
    deductions: [{label: 'ภาษี', amount: '2000.05'}],
    reimbursements: [{label: 'เบิกคืน', amount: '0.00'}],
    arrears: [{label: 'ยอดปรับ', amount: '-0.01'}],
  });
  assert.deepEqual(visited, ['checkForAttMethod_v2', 'getEmpPayrollYear', 'getEmpPayrollMonth', 'payrollEncryption', 'getEmpSalary']);
});

test('payslip PDF keeps the bytes from the official employee-scoped response', async t => {
  await testWithProvider(t);
  const response = await invoke({action: 'pdf', year: '2026', period});
  assert.equal(response.statusCode, 200);
  assert.equal(response.headers['Content-Type'], 'application/pdf');
  assert.match(response.headers['Content-Disposition'], /^attachment/);
  assert.deepEqual(response.body, fakePdf);
});

test('payslips reject missing sessions, changed accounts and missing payroll access before upstream', async t => {
  const {visited} = await testWithProvider(t);
  assert.equal((await invoke({action: 'years'}, {input: null})).statusCode, 401);
  assert.equal((await invoke({action: 'years', employee: 'other'})).body.code, 'payslip_account_changed');
  assert.equal((await invoke({action: 'years'}, {input: {...session, payrollKey: ''}})).body.code, 'payslip_unavailable');
  assert.deepEqual(visited, []);
});

test('payslips reject periods outside the issued list and data returned for another employee', async t => {
  const {visited} = await testWithProvider(t, {owner: 'different-account'});
  const invalidPeriod = await invoke({action: 'detail', year: '2026', period: 'unknown'});
  assert.equal(invalidPeriod.body.code, 'payslip_period_invalid');
  assert(!visited.includes('payrollEncryption'));
  const response = await invoke({action: 'detail', year: '2026', period});
  assert.equal(response.body.code, 'payslip_invalid');
});

test('payslips do not guess an unsupported pay group or fetch an external document', async t => {
  const provider = await testWithProvider(t, {group: '1'});
  assert.equal((await invoke({action: 'detail', year: '2026', period})).body.code, 'payslip_group_required');
  assert.deepEqual(provider.visited, ['checkForAttMethod_v2', 'getEmpPayrollYear']);
  const external = mockProvider({source: 'https://external.example'});
  globalThis.fetch = external.fetcher;
  const response = await invoke({action: 'pdf', year: '2026', period});
  assert.equal(response.body.code, 'payslip_invalid');
  assert.equal(external.visited.at(-1), 'getEmpPaySlip');
});
