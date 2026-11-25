# HumanSoft 3.61: หลักฐานการแกะแอปและการเชื่อม FUQ HONO

ตรวจวันที่ 25 พฤศจิกายน 2026 โดยใช้ไฟล์ XAPK ที่ผู้ใช้แนบมาโดยตรง

## ผลที่ยืนยันแล้ว

1. แอปพนักงานคือ `th.co.humansoft.app`, เวอร์ชัน **3.61**, version code **606**
2. ใช้ Flutter/Dart AOT; Android launcher ลงทะเบียน Flutter plugins เท่านั้น ไม่ได้ประกอบคำขอลงเวลาใน Java
3. พบชื่อไฟล์ Dart สำหรับ Login, ตรวจใบหน้า, ตรวจตำแหน่ง, กะงาน, กันลงเวลาซ้ำ และส่งลงเวลา รวมถึงชื่อเส้นทาง API ใน `libapp.so`
4. ทดสอบ Login ใหม่ด้วยบัญชีที่ผู้ใช้อนุญาตสำเร็จ ผ่านบริการ HRS **web**: HTTP 200 / application code 200, ได้ session token และตรวจว่าบัญชี/บริษัทตรงกัน
5. `PSDGROUP` มีหลายบริษัท ต้องเลือกช่องบริษัท **NWL** โดยเจาะจง ห้ามเลือกบริษัทแรกในรายการ
6. ยังไม่มีการส่งลงเวลาจริง และยังไม่ยืนยัน payload ลงเวลาของ Android ว่าครบถ้วน

การ Login สำเร็จข้างต้นเป็นการส่ง user/password ใหม่ ไม่ได้อาศัย cookie จาก browser ที่เปิดค้างอยู่ แต่เป็นการทดสอบ **web login contract** ไม่ใช่การรัน Android APK และไม่ใช่หลักฐานว่าลงเวลาสำเร็จ

## ไฟล์ต้นทางและวิธีตรวจ

| รายการ | หลักฐาน |
| --- | --- |
| ไฟล์ที่ผู้ใช้แนบ | `HumanSoft_3.61_APKPure.xapk`, 99,576,173 bytes |
| XAPK SHA-256 | `3c03940822e00f37bc563c000fc95069bdd81bd36966604797bd13e227f15dde` |
| Base APK SHA-256 | `7af4b29310f784b5b64a70f468d00afb46ed9cc1e50c3ba1bafb369558a3bb06` |
| `libapp.so` SHA-256 | `56631020382b4f9f29d1634267371dad57574796a3eac6deb72e6715071009a3` |
| Dart snapshot | unified, FullAOT kind 2; arm64-v8a |
| REA | 6.8.0 สำหรับ Android/JADX, 6.10.1 สำหรับ unified Dart snapshot |
| JADX headless | 0.7.1; Java 21; heap 1024 MiB; worker 1 |

ใช้ [morluto/rea](https://github.com/morluto/rea) ตามที่ผู้ใช้ระบุ ตรวจ package, class inventory และ method ตามลำดับ จากนั้นตรวจ Flutter AOT แยกต่างหาก เก็บ evidence ID ใน [humansoft-rea-evidence.json](humansoft-rea-evidence.json)

REA 6.8.0 อ่าน snapshot แบบ unified ไม่ได้ จึงเก็บ error ไว้และตรวจใหม่ด้วย 6.10.1 ซึ่งอ่านโครงสร้าง snapshot ได้สำเร็จ การอ่าน string pool ยังมีขอบเขตจำกัด และ **ไม่ได้ถอด Dart กลับเป็น source code หรือพิสูจน์ call graph ของการลงเวลา**

หลักฐาน Java ที่ตรวจ method จริง:

- Class: `th.co.humansoft.app.MainActivity`
- Method: `configureFlutterEngine(io.flutter.embedding.engine.FlutterEngine): void`, overload 0
- Body เรียก `GeneratedPluginRegistrant.registerWith(flutterEngine)`
- Evidence: `ev_e205f3915fc9758db8fb656ca5908a8a03694192ff9e781ce0cbe6fc4b64fd2e`

## สิ่งที่พบจาก binary แอปโดยตรง

| ส่วน | ชื่อ source URI ใน `libapp.so` | ระดับการยืนยัน |
| --- | --- | --- |
| Login | `screens/authen/login/login_new_ctrl.dart`, `services/auth_service/auth_service.dart`, `auth_session.dart` | พบชื่อใน binary |
| ประกอบ API | `services/check_in_services/check_in_api_service.dart`, `http_adapter.dart` | พบชื่อ; ยังไม่ถอด request builder |
| ตรวจตำแหน่ง | `services/check_in_services/location_validation_service.dart` | พบชื่อ; ยังไม่รู้เงื่อนไขบริษัทนี้ |
| กันลงเวลาซ้ำ | `services/check_in_services/duplicate_time_validator_service.dart` | พบชื่อ; ยังไม่รู้ช่วงเวลาที่ใช้ตัดซ้ำ |
| กะงาน | `services/check_in_services/work_cycle_service.dart` | พบชื่อ; ต้องอ่านกะจริงก่อนเลือกวันทำงาน |
| ตรวจภาพ | `services/face_capture/face_capture_image_validator.dart` | พบชื่อและข้อความสำหรับภาพมืด ย้อนแสง หน้าขาด หลายใบหน้า |
| ลงเวลาแบบใบหน้า | `services/time_attendance_services/face_time_attendance_service.dart` | พบชื่อ; ยังไม่ยืนยันการส่งผล match |
| ลงเวลาวิธีอื่น | `normal_time_attendance_service.dart`, `offline_time_attendance_service.dart`, `wifi_time_attendance_service.dart`, `beacon_time_attendance_service.dart` | พบชื่อ; ไม่ได้แปลว่า NWL เปิดใช้ทุกวิธี |

ชื่อเส้นทางที่พบตรงตัว:

```text
/api/v1/hrs/time_attendance/add_time_attendance_mobile_4
/api/v1/hrs/time_attendance/re_add_time_attendance_mobile
/api/v1/hrs/work_cycles/get_attendance_work_cycle
/api/v1/hrs/work_cycles/get_work_cycle_by_employee_id
```

ชื่อข้อมูล/การทำงานที่พบ ได้แก่ `verify_face_by_person`, `verify_attendance`, `attendance_image_base64`, `attendance_datetime`, `work_cycle_date`, `time_attendance_type_lv`, `latitude`, `longitude`, `location_id`, `device_sn`

**ข้อจำกัด:** ชื่อเหล่านี้เป็น static literals อาจมาจาก code ที่ไม่ได้ถูกเรียกหรือ validator ที่ใช้ร่วมกัน ยังไม่ใช่รายการ required fields และยังไม่ได้ยืนยันว่าผูกกับ API เส้นใด/host ใด การจับคู่ด้วยการเดาแล้วส่งจริงอาจสร้างรายการผิด จึงไม่มีการทำเช่นนั้น

ดู byte offsets และรายการชื่อที่เลือกไว้ใน [humansoft-3.61-inventory.json](humansoft-3.61-inventory.json) สร้างซ้ำได้โดยไม่รันแอป:

```bash
python scripts/reverse/humansoft_inventory.py /path/HumanSoft_3.61_APKPure.xapk \
  --output /path/humansoft-inventory.json
```

## Login contract ที่ตรวจด้วยเว็บและทดสอบจริง

พบจาก public JavaScript ของ `https://hrs.humansoft.co.th/auth/login` และทดสอบ HTTP แยกจาก Android:

| ขั้น | Transport / ข้อมูล |
| --- | --- |
| ค้นองค์กร | POST JSON `https://web-core.humansoft.co.th/api-web.php` |
| Action ค้นองค์กร | `_compgrp=hrs`, `_comp=sites`, `_action=get_instance_server_code`, `instance_server_code=PSDGROUP` |
| เลือกบริษัท | รายการ `INSTANCE_SERVER_CHANNELS` ที่ `company_code=NWL` เท่านั้น |
| Login | URL เดิม, `_compgrp=hrs`, `_comp=users`, `_action=identifier_user` |
| Credentials | `user_name`, `user_psw` ใน JSON body ผ่าน HTTPS |
| IDs | `instance_server_id`, `instance_server_channel_id` เป็น Base64 ของ ID ที่ได้จริง; ไม่ใช่ token และไม่ใช่ encryption |
| ค่าเริ่มต้น | `identify_user_id=""`, `employee_id=""`, `language_code=TH` |
| ผลสำเร็จ | code 200, JWT มีค่า, employee และ channel ตรงกับบัญชีที่ขอ |

Public bundles ที่ใช้ตรวจประกอบ: `main-CV2SP6ZE.js`, `chunk-BNA3jvuZ.js`, `chunk-CTkDEf47.js` บน origin ข้างต้น โค้ดเว็บอาจเปลี่ยนได้โดยไม่ตรงกับ APK 3.61 จึงแยกแหล่งหลักฐานไว้ชัดเจน

บันทึกผลทดสอบที่ตัดข้อมูลส่วนบุคคลออกแล้วใน [humansoft-readonly-validation.json](humansoft-readonly-validation.json) ไม่เก็บ password, token, profile, salary, company IDs หรือ raw response ใน Git

เตรียมโมดูลต้นแบบ `server/humansoft-auth.js` และ automated tests แล้ว โมดูลเลือก NWL อย่างเจาะจง ตรวจ account mismatch และหยุดเมื่อจำเป็นต้องเปลี่ยนรหัส/MFA ไม่มีการต่อเข้ากับ production route และไม่มี API เขียนลงเวลา

## ลงเวลาครั้งเดียวส่งสองระบบได้หรือยัง

**Login ด้วย credentials ชุดเดียวกันได้แล้วสำหรับบัญชีที่ทดสอบ ส่วนการลงเวลาคู่ยังไม่ผ่านการพิสูจน์ครบวงจร**

แนวทาง implementation:

1. Login HONO และ HumanSoft แยกกัน ใช้ credentials ชุดเดียวตามที่ผู้ใช้เลือก โดยรองรับผลสำเร็จ/ผิดพลาดแยกกัน และเก็บ session ฝั่ง server
2. อ่านนโยบายลงเวลา ตำแหน่งที่อนุญาต กะงาน และประวัติของบัญชีนี้จากทั้งสองระบบก่อนเปิดปุ่มลงเวลา
3. ถ่ายภาพสดครั้งเดียวได้ในระดับ UX แต่แต่ละระบบต้องตรวจภาพกับข้อมูลใบหน้าของตนเอง ผล verify หรือ proof ของ HONO ใช้แทน HumanSoft ไม่ได้โดยอัตโนมัติ
4. ใช้ตำแหน่งจริงตามนโยบาย HumanSoft ไม่ถือว่าพิกัด Thai CC ที่เลือกใน HONO เป็นหลักฐานว่าผู้ใช้อยู่ตรงนั้น
5. สร้างรายการปฏิบัติการที่เก็บถาวร มีสถานะและผลตอบรับรายระบบ ตรวจประวัติก่อน retry เมื่อ timeout และ retry เฉพาะระบบที่ยังไม่ยืนยันผล ห้ามส่ง HONO ซ้ำเพราะ HumanSoft ผิดพลาด
6. แยกสถานะ `กำลังส่ง`, `เข้าคิว`, `ยืนยันสำเร็จ`, `ไม่สำเร็จ`, `ยังไม่ทราบผล` ห้ามแสดงว่าสองระบบสำเร็จเพียงเพราะได้ HTTP 200

ตัวอย่างผลลัพธ์: HONO สำเร็จ / HumanSoft รอประมวลผล ต้องแสดงตามนั้น ไม่เปลี่ยนสองช่องเป็นสีเขียวพร้อมกันจาก animation

## อีกช่องทางที่มีเอกสารทางการ

[HumanSoft Open API](https://docs.humansoft.co.th/docs/get-started) ใช้ subscription key ที่ผู้ดูแลบริษัทเปิดสิทธิ์ให้ ไม่ใช่ employee password

มี [POST time-attendance/submit](https://docs.humansoft.co.th/docs/api-reference/time-attendance/submit) โดยผล `successfully en-queued` หมายถึงเข้าคิว ไม่ใช่ยืนยันบันทึกเสร็จ ช่องทางนี้เป็นคนละ contract กับ mobile API ใน APK ต้องเลือกให้ชัดก่อนพัฒนา และไม่ใช้ API key ที่ติดมากับแอป/เว็บแทนสิทธิ์ที่บริษัทให้

## เทียบ payload สำหรับปุ่มลงเวลาครั้งเดียว

### หลักฐานเฉพาะหน้าลงเวลาในแอป 3.61

REA พบ `check_in_data_model.dart`, `check_in_duplicate_time_model.dart`, `check_in_location_model.dart` และ `check_in_result_model.dart` ใน Dart snapshot ของ arm64 (evidence `ev_62a0bc99e8b5213e198c5f43e52039cdfeeb0267d033409b0fa90422524ccc5d`) ภายใน base APK มีไฟล์ `assets/flutter_assets/assets/translations/th.json` ซึ่งให้ความหมายของข้อมูลเหล่านี้เพิ่มจากการค้นชื่อใน binary

- `check_in_new.payload_validation` มีข้อความแจ้งว่าข้อมูลที่ต้องกรอกขึ้นกับ `serviceType` และมีป้ายสำหรับเวลาลงรายการ พนักงาน ผู้ใช้ วิธีลงเวลา วันของกะ ประเภทกะ ลำดับวันทำงาน และเวลาซ้ำ ในกลุ่มเดียวกันมีข้อความขอ latitude, longitude, Location ID หรือข้อมูลอุปกรณ์ตามวิธีลงเวลา
- หน้าลงเวลามีข้อความสำหรับตำแหน่งปัจจุบัน ระยะห่างจากพื้นที่ วันที่ของกะข้ามวัน เวลาสุดท้ายในระบบ และระยะห่างเป็นนาทีที่ใช้พิจารณารายการซ้ำ ไม่มีตัวเลขช่วงกันซ้ำของ NWL ในหลักฐานชุดนี้
- ป้าย `check_in_new.check_in` ภาษาไทยคือ **ลงเวลา** และ `face_verified_local_success` กล่าวถึงการยืนยันใบหน้าบนอุปกรณ์ การตรวจภาพผ่านกับการบันทึกเวลาสำเร็จจึงควรแสดงคนละสถานะ [คู่มือ HumanSoft](https://www.humansoft.co.th/th/document/checkin-by-application) อธิบายว่าประวัติสีเทาคือรายการรอเข้าฐานหลักและสีดำคือรายการที่เข้าระบบแล้ว

ขอบเขตของหลักฐานคือคำที่แอปใช้กับหน้าจอและข้อผิดพลาด ยังต้องตรวจ contract ของ mobile build หรือผลบนเครื่องทดสอบเพื่อระบุฟิลด์บังคับรายวิธี การแยกเข้า/ออก และการส่งรูปของ NWL อย่างแน่นอน

ตรวจเส้นทางเว็บจาก `lib/data/hono_web.dart` ผ่าน `api/[route].js` ไปถึง `server/hono.js` และรัน `submit` ตัวจริงด้วยภาพ PNG สังเคราะห์และ fetch จำลองใน process ทั้ง `I` และ `O` ส่ง `POST UserVisitProfileImage` ด้วย multipart 8 ฟิลด์ ได้แก่ `comp_code`, `api_key`, `userid`, `status`, `punch`, `lat`, `lng`, `profile_image_url` ทั้งสองกรณี การทดสอบนี้ตรวจรูปแบบคำขอขาออกและชนิดไฟล์โดยไม่สร้างรายการลงเวลา

| ข้อมูล | FUQ HONO เว็บ → HONO | HumanSoft Open API เมื่อใช้ GPS |
| --- | --- | --- |
| บัญชี | Backend อ่าน `userid` และข้อมูลบริษัทจาก session | `employee_code` จากบัญชี HumanSoft ที่จับคู่กับพนักงานเดียวกัน ระบบเชื่อมต่อต้องมี subscription key |
| เข้า/ออก | ปุ่มเลือก `punch` เป็น `I` หรือ `O` | `time_attendance_type_lv=Checkin` ระบุวิธี GPS ทั้งเข้าและออก เอกสาร submit ไม่ระบุฟิลด์เลือกทิศทาง ต้องเทียบผลในประวัติทั้งสองครั้ง |
| เวลา | multipart ไม่มีช่องกำหนดเวลา | `attendance_datetime` เป็นเวลาของเหตุการณ์ และ `work_cycle_date` เป็นวันของกะ HumanSoft ซึ่งอาจเป็นวันก่อนหน้าสำหรับกะข้ามคืน |
| สถานที่ | Browser ส่ง lat/lng ของ `Place` ที่เลือก ถ้าเลือกจาก HONO จะส่ง `workLocation` ให้ backend ตรวจอีกครั้ง | ใช้ `location_id` ของสถานที่ที่พนักงานมีสิทธิ์ใน HumanSoft และ `latitude`/`longitude` จากการวัดบนอุปกรณ์ ถ้าคำขอเดิมมีเพียงพิกัดหมุดต้องขอตำแหน่งอุปกรณ์เพิ่ม |
| ภาพ | Backend ตรวจ `proof` กับ JPEG ที่รับ แล้วสร้างไฟล์ PNG สำหรับ `profile_image_url` | `image_path` เป็น URL ทางเลือกตามเอกสาร การแนบภาพกับการผ่านการเทียบใบหน้าเป็นคนละผลลัพธ์ ต้องยืนยันขั้นตอนตรวจใบหน้าที่ NWL เปิดไว้ |

ข้อสังเกตในการทดสอบ UAT: หน้าคู่มือ [Locations](https://docs.humansoft.co.th/docs/api-reference/locations/get-list) ระบุว่าผลลัพธ์ `location_id` เป็น raw และบอกให้นำไปใช้ได้โดยตรง แต่ [Submit](https://docs.humansoft.co.th/docs/api-reference/time-attendance/submit) กำหนด Base64 และตรวจรูปแบบนี้ ควรใช้สัญญาฝั่ง submit เป็นจุดเริ่มต้นและตรวจผลใน UAT ด้วย ID จริงของบัญชีทดสอบ

ข้อมูลในคอลัมน์ HumanSoft มาจาก Open API ส่วน body ของ `add_time_attendance_mobile_4` ในแอป 3.61 ยังไม่มีหลักฐานขณะรันที่บอกว่าค่าใดไปกับ request นี้ ต้องใช้ตัวอย่างคำขอและผลจากระบบทดสอบของ HumanSoft ที่ตัดข้อมูลส่วนบุคคลและข้อมูลยืนยันตัวตนออก หรือใช้ contract ที่ผู้ให้บริการรับรอง สำหรับกรณีเข้าและออกของ NWL

เมื่อเชื่อมจริง ให้ตรวจความพร้อมทั้งคู่ก่อนส่ง สร้างรหัสรายการเดียว บันทึกสถานะรายระบบลงฐานข้อมูล แล้วเริ่มสองคำขอพร้อมกัน เวลาอ้างอิงของ HumanSoft ต้องคงเดิมเมื่อกลับมาเทียบผล ส่วนเวลาที่ปรากฏใน HONO ให้ยึดจากประวัติ HONO ถ้าฝั่งหนึ่งสำเร็จและอีกฝั่งเข้าคิว/เครือข่ายขาด ให้ตรวจประวัติของฝั่งที่ค้างก่อนพิจารณาส่งใหม่

## ช่องว่างที่ยังต้องพิสูจน์

| เรื่อง | สถานะ |
| --- | --- |
| ไฟล์/version/hash จาก XAPK ที่แนบ | ผ่าน |
| Android launcher และ Flutter snapshot inventory | ผ่านภายในขอบเขต static inspection |
| Fresh employee web login สำหรับ PSDGROUP/NWL | ผ่าน |
| Mobile request builder → body/header → response model | ยังเชื่อมเส้นทางไม่ครบ |
| นโยบาย face/location และกะจริงของ HumanSoft/NWL | ยังไม่ได้ตรวจ |
| นำภาพสดเดียวส่งตรวจแยกสองระบบ | ยังไม่ได้ทดสอบ |
| รายการจริงปรากฏใน HumanSoft หลังส่ง | ยังไม่ได้ทดสอบ; ไม่สร้าง attendance เพื่อทดลอง |
| Retry ข้าม serverless instances โดยไม่ซ้ำ | ต้องเพิ่ม durable operation store ก่อนเปิด dual write |
| iPhone/Android camera และ UX แบบสองระบบ | ยังไม่ได้ทดสอบ integration |

ทดสอบ `npm test` ผ่าน 46 tests รวม HumanSoft auth 7 tests (mock transport), ทดสอบ extractor กับ XAPK ที่แนบจริงได้ 24 selected literals และ 45 selected source URIs, และ `git diff --check` ผ่าน การตรวจรายการใหม่ไม่พบ credentials หรือ JWT ของบัญชีจริงในไฟล์ที่จะส่ง Git เครื่องมือนี้ไม่มี Android emulator/ADB หรือ native decompiler ที่ตั้งค่าพร้อมใช้ จึงยังไม่ได้เก็บ Android runtime trace

ขั้นต่อไปคือ runtime trace จากแอปบนเครื่องทดสอบของบัญชีที่ได้รับอนุญาต หรือถอด native request builder ต่อจนเชื่อม body/header/ผลตอบรับครบ ต้องไม่แก้ production attendance ให้ข้ามการตรวจสอบเพื่อชดเชยข้อมูลที่ยังไม่รู้

## ขอบเขตการเปลี่ยนแปลง

เพิ่มเฉพาะรายงาน, inventory ที่ตัดข้อมูลอ่อนไหว, ตัวตรวจ XAPK และต้นแบบ auth พร้อม tests ไม่เปลี่ยนหน้าเว็บ, HONO auth, backend contract เดิม หรือ production deployment เก็บ APK, third-party source เต็ม, credentials และ traffic ที่มีข้อมูลส่วนตัวนอก Git

REA เป็น upstream MIT; ใช้เป็นเครื่องมือวิเคราะห์ ไม่คัดลอก code ของ HumanSoft เข้าผลิตภัณฑ์ โค้ด adapter และ inventory ที่เพิ่มใน repository เขียนขึ้นสำหรับงานนี้
