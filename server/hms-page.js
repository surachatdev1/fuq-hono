const results = {
  verified: 'HumanSoft ยืนยันการเข้าสู่ระบบแล้ว',
  expired: 'คำขอหมดอายุหรือเปิดจากอีกเบราว์เซอร์ กรุณาเริ่มเข้าสู่ระบบอีกครั้ง',
  failed: 'ยังยืนยันผลจาก HumanSoft ไม่ได้ กรุณาลองอีกครั้ง',
  cancelled: 'ยกเลิกการเข้าสู่ระบบแล้ว'
};

// Only fixed URLs and messages are rendered. All authentication happens on HumanSoft.
export function hmsPage({ client, outcome, portal }) {
  const status = Object.hasOwn(results, outcome) ? results[outcome] : '';
  return `<!doctype html>
<html lang="th"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>HumanSoft สำหรับพนักงาน · FUQ HONO</title><link rel="stylesheet" href="/hms.css"></head>
<body><header><a href="/" aria-label="กลับ FUQ HONO" class="brand">FUQ HONO</a><span>พอร์ทัลพนักงาน</span></header>
<main><div class="art"><img src="/assets/assets/cinematic/login.webp" alt="" fetchpriority="high"></div>
<section><h1>เข้าสู่ระบบ<br><b lang="en">HumanSoft</b></h1>
<p>ทดสอบบัญชีพนักงานของคุณบนเว็บไซต์ HumanSoft</p>
<dl><div><dt>โดเมนบริษัท</dt><dd>PSDGROUP</dd></div><div><dt>บริษัทสังกัด</dt><dd>NWL</dd></div></dl>
${status ? '<p role="status" class="status">' + status + '</p>' : ''}
<a class="primary" href="${client ? '/api/hms?start=1' : portal}">เข้าสู่ระบบ HumanSoft <span aria-hidden="true">↗</span></a>
<p class="hint">${client ? 'เมื่อยืนยันบัญชีแล้ว ระบบจะพากลับมาแสดงผลที่หน้านี้' : 'ที่หน้า HRS ให้กรอก PSDGROUP เลือก NWL แล้วใช้บัญชีพนักงานของคุณ'} การเข้าสู่ระบบอย่างเดียวจะยังไม่บันทึกเวลา</p>
<details><summary>ลงเวลาผ่านแอป HumanSoft</summary><p>เปิดแอป HumanSoft บนมือถือ เลือกเมนูลงเวลา แล้วทำตามวิธีที่ NWL เปิดให้บัญชีของคุณ</p>
<nav aria-label="แอปและคู่มือลงเวลา"><a href="https://apps.apple.com/th/app/humansoft/id1533922283">App Store</a>
<a href="https://play.google.com/store/apps/details?id=th.co.humansoft.app">Google Play</a>
<a href="https://www.humansoft.co.th/th/document/work-time-recording">คู่มือลงเวลา</a></nav></details>
</section></main></body></html>`;
}
