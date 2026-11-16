import {Failure, request, requireResult, state, value} from './hono.js';

const payrollPaths = {
  years: 'getEmpPayrollYear',
  periods: 'getEmpPayrollMonth',
  identity: 'payrollEncryption',
  detail: 'getEmpSalary',
  pdf: 'getEmpPaySlip',
};

export const canReadPayslips = session =>
  session.company.toLowerCase() === 'psd' && Boolean(session.payrollKey);

const invalidData = () =>
  new Failure('HONO ส่งข้อมูลสลิปไม่ครบหรือผิดรูปแบบ', 502, 'payslip_invalid');
const invalidPeriod = () =>
  new Failure('กรุณาเลือกงวดจากรายการของ HONO', 400, 'payslip_period_invalid');

function payroll(session, action, fields, signal) {
  const url = new URL('../PayrollData/' + payrollPaths[action], session.base);
  url.search = new URLSearchParams({
    comp_code: session.company,
    api_key: session.payrollKey,
    ...fields,
  });
  // Keep the exact spelling of numeric amounts, even when HONO sends numbers.
  return request(url, {signal}, text => JSON.parse(text, (_, item, context) =>
    typeof item === 'number' ? context.source : item,
  ));
}

function options(rows, id, label = id) {
  if (!Array.isArray(rows)) throw invalidData();
  const byId = new Map();
  for (const row of rows) {
    const code = value(row, id), title = value(row, label);
    if (!code || code.length > 64 || !title || title.length > 128) {
      throw invalidData();
    }
    if (byId.has(code) && byId.get(code).label !== title) throw invalidData();
    byId.set(code, {id: code, label: title});
  }
  return Array.from(byId.values());
}

function validateYear(year) {
  // FY values can describe fiscal years, for example 2025-2026.
  if (typeof year !== 'string' || !/^\d{4}(?:\s*[-/]\s*\d{2,4})?$/.test(year)) {
    throw invalidPeriod();
  }
}

async function listPeriods(session, year, signal) {
  const data = requireResult(await payroll(session, 'periods', {
    emp_code: session.employee,
    year,
  }, signal));
  return {
    options: options(data.MONTH, 'MONTHCODE', 'PAYDATE'),
    selected: value(data, 'CURRENT_CODE'),
  };
}

function money(amount, optional = false) {
  if (optional && (amount == null || amount === '')) return null;
  if (typeof amount !== 'string' || amount.length > 64 ||
      !/[0-9]/.test(amount) || !/^[0-9.,+\-()\s]+$/.test(amount)) {
    throw invalidData();
  }
  return amount;
}

function lineItems(rows) {
  if (rows == null) return [];
  if (!Array.isArray(rows)) throw invalidData();
  return rows.map(row => {
    if (typeof row?.Payhead !== 'string' || !row.Payhead.trim() ||
        row.Payhead.length > 300) throw invalidData();
    return {label: row.Payhead, amount: money(row.Value, true)};
  });
}

function addressOfPdf(session, data) {
  const upstream = new URL(session.base);
  const knownHosts = [upstream.hostname, session.company.toLowerCase() + '.honohr.com'];
  const rawPath = data.path;
  if (typeof rawPath !== 'string' || !rawPath.startsWith('/') ||
      rawPath.startsWith('//') || /[\u0000-\u0020\\]/.test(rawPath)) throw invalidData();
  const origin = new URL(data.url || 'https://' + session.company.toLowerCase() + '.honohr.com');
  if (origin.search || origin.hash) throw invalidData();
  const url = new URL(origin.href.replace(/\/$/, '') + rawPath);
  if (url.protocol !== 'https:' || url.port || url.username || url.password ||
      url.hash || !knownHosts.includes(url.hostname)) throw invalidData();
  return url;
}

async function downloadPdf(session, fields, signal) {
  const data = requireResult(await payroll(session, 'pdf', fields, signal));
  const url = addressOfPdf(session, data);
  const response = await fetch(url, {
    redirect: 'error',
    signal: AbortSignal.any([signal, AbortSignal.timeout(12000)]),
  });
  if (!response.ok || !response.body) throw invalidData();
  const limit = 3_500_000;
  const blocks = [];
  let size = 0;
  for await (const block of response.body) {
    size += block.length;
    if (size > limit) {
      throw new Failure('ไฟล์สลิปมีขนาดใหญ่ กรุณาดาวน์โหลดจาก HONO', 502, 'payslip_pdf_size');
    }
    blocks.push(block);
  }
  const file = Buffer.concat(blocks);
  if (file.subarray(0, 5).toString() !== '%PDF-') throw invalidData();
  return {pdf: file};
}

export async function readPayslips(session, input) {
  if (!canReadPayslips(session)) {
    throw new Failure('บัญชีนี้ยังไม่สามารถเปิดสลิปเงินเดือนผ่านเว็บได้', 403, 'payslip_unavailable');
  }
  if (input.company !== session.company || input.employee !== session.employee) {
    throw new Failure('บัญชีที่เข้าสู่ระบบเปลี่ยนแล้ว กรุณาเปิดหน้าสลิปใหม่', 403, 'payslip_account_changed');
  }
  const {action, year, period} = input;
  if (typeof action !== 'string' || !Object.hasOwn(payrollPaths, action) ||
      action === 'identity') throw invalidPeriod();
  if (action !== 'years') validateYear(year);
  if ((action === 'detail' || action === 'pdf') &&
      (typeof period !== 'string' || !period || period.length > 64)) {
    throw invalidPeriod();
  }

  // The legacy payroll calls use a company key. Confirm the upstream
  // employee session first and derive every employee field on the server.
  await state(session);
  const signal = AbortSignal.timeout(22000);
  const data = requireResult(await payroll(session, 'years', {
    emp_code: session.employee,
  }, signal));
  if ([data.paygroupFlag, data.sitewiseFlag].some(flag =>
    !/^(?:0|false)?$/i.test(String(flag ?? '').trim()),
  )) {
    throw new Failure('บริษัทกำหนดกลุ่มจ่ายหรือไซต์ กรุณาเปิดสลิปจาก HONO', 409, 'payslip_group_required');
  }
  const years = options(data.finYear, 'FY');
  if (action === 'years') return {options: years, selected: value(data, 'Selected')};
  if (!years.some(option => option.id === year)) throw invalidPeriod();

  const periods = await listPeriods(session, year, signal);
  if (action === 'periods') return periods;
  const selected = periods.options.find(option => option.id === period);
  if (!selected) throw invalidPeriod();

  const employee = requireResult(await payroll(session, 'identity', {
    emp_code: session.employee,
    action: 'encrypt',
  }, signal)).data;
  if (typeof employee !== 'string' || !employee.trim() || employee.length > 1024) {
    throw invalidData();
  }
  const fields = {emp_code: employee, month: selected.id, year};
  if (action === 'pdf') return downloadPdf(session, fields, signal);

  const slip = requireResult(await payroll(session, 'detail', {
    ...fields, paygroup: '', site: '',
  }, signal));
  if (slip.emp_code != null &&
      ![session.employee, employee].includes(value(slip, 'emp_code'))) throw invalidData();
  return {
    period: selected,
    summary: {
      gross: money(slip.salary?.GROSSPAY),
      deductions: money(slip.salary?.GROSSDED),
      net: money(slip.salary?.NETPAY),
    },
    earnings: lineItems(slip.Earning),
    deductions: lineItems(slip.Deduction),
    reimbursements: lineItems(slip.Reimbursement),
    arrears: lineItems(slip.Arrear),
  };
}
