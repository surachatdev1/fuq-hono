const results = {
  verified: 'HumanSoft ยืนยันการเข้าสู่ระบบแล้ว',
  expired: 'คำขอหมดอายุหรือเปิดจากอีกเบราว์เซอร์ กรุณาเริ่มเข้าสู่ระบบอีกครั้ง',
  failed: 'ยังยืนยันผลจาก HumanSoft ไม่ได้ กรุณาลองอีกครั้ง',
  cancelled: 'ยกเลิกการเข้าสู่ระบบแล้ว'
};

// Only fixed URLs and messages are rendered. All authentication happens on HumanSoft.
export function hmsPage({ client, outcome, portal, attendance = false }) {
  const status = Object.hasOwn(results, outcome) ? results[outcome] : '';
  const actions = attendance ? `
<h1>ลงเวลางาน<br><b lang="en">HumanSoft</b></h1>
<p>เลือกช่องทางที่ NWL เปิดให้บัญชีหรืออุปกรณ์ของคุณ</p>
<a class="primary" href="https://line.me/R/ti/p/@app.humansoft">เปิด HumanSoft ใน LINE <span aria-hidden="true">↗</span></a>
<p class="hint">เปิดแชต @app.humansoft แล้วเลือก “ลงเวลางาน” ผูกบัญชีพนักงานใน LINE หากเข้าใช้ครั้งแรก</p>
<a class="secondary" href="https://timeapp.humansoft.co.th/#/timeapp/config">ลงเวลาบนเครื่องของบริษัท <span aria-hidden="true">↗</span></a>
<p class="hint">Time Web ใช้กับเครื่องที่ NWL ขึ้นทะเบียนไว้และมีรหัสอุปกรณ์สำหรับสแกนใบหน้าหรือ QR</p>
<details><summary>ใช้แอป HumanSoft บนมือถือ</summary><p>เปิดแอป HumanSoft ของพนักงาน แล้วเลือกเมนูลงเวลาตามปกติ</p>
<nav aria-label="ดาวน์โหลดแอปพนักงาน"><a href="https://apps.apple.com/th/app/humansoft/id1533922283">App Store</a>
<a href="https://play.google.com/store/apps/details?id=th.co.humansoft.app">Google Play</a></nav></details>
<a class="back" href="/hms">กลับหน้าล็อกอิน HumanSoft</a>` : `<h1>เข้าสู่ระบบ<br><b lang="en">HumanSoft</b></h1>
<p>ทดสอบบัญชีพนักงานของคุณบนเว็บไซต์ HumanSoft</p>
<dl><div><dt>โดเมนบริษัท</dt><dd>PSDGROUP</dd></div><div><dt>บริษัทสังกัด</dt><dd>NWL</dd></div></dl>
${status ? '<p role="status" class="status">' + status + '</p>' : ''}
<a class="primary" href="${client ? '/api/hms?start=1' : portal}">เข้าสู่ระบบ HumanSoft <span aria-hidden="true">↗</span></a>
<p class="hint">${client ? 'เมื่อยืนยันบัญชีแล้ว ระบบจะพากลับมาแสดงผลที่หน้านี้' : 'ที่หน้า HRS ให้กรอก PSDGROUP เลือก NWL แล้วใช้บัญชีพนักงานของคุณ'} การเข้าสู่ระบบอย่างเดียวจะยังไม่บันทึกเวลา</p>

<a class="secondary" href="/hms/attendance">ลงเวลาทำงาน <span aria-hidden="true">→</span></a>`;
  return `<!doctype html>
<html lang="th"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${attendance ? 'ลงเวลางาน' : 'เข้าสู่ระบบ'} HumanSoft · FUQ HONO</title><link rel="stylesheet" href="/hms.css"></head>
<body><header><a href="/" aria-label="กลับ FUQ HONO" class="brand">FUQ HONO</a><span>พอร์ทัลพนักงาน</span></header>
<main><div class="art"><img src="/assets/assets/cinematic/login.webp" alt="" fetchpriority="high"></div>
<section>${actions}</section></main></body></html>`;
}
