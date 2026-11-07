# Processed calendar, local alarms and lean build — 1.2

## Correct lateness source

1.1 incorrectly calculated lateness from `Service/UserVisitFetchRecords_v2` raw punches. Those are retained solely as raw history and capture preflight evidence. 1.2 calculates monthly lateness from the company attendance calendar's `startTime`, with `endTime` displayed beside it. No fallback to raw punch time is allowed. Manual calendar overrides affect alarms only; they cannot hide a processed late workday from the monthly report. Missing, unreadable or pending calendar rows remain incomplete; no guessed zero or HR warning letter is produced.

The verified read endpoint is `sapi/CalendarMaster/showCalendar_v2`, obtained from HONO Android 22.9/323 (APK SHA256 `99440c33ecda95a3ac9eac329d7874fef80c804ccc55ed977e6756ada71ef9dc`)'s URL builder and calendar response handler. It uses the `CALENDAR` API key, base64 URL envelope with the legacy prefix/suffix and `type=android`. Request fields: `comp_code`, `api_key`, `emp_code`, `from_date`, `to_date`, `role=Employee`, `loggedin_user`, `token`. Both employee fields are scoped to the authenticated employee. Dates are ISO `yyyy-MM-dd`. The UI never exposes another employee selector.

Response `show_calendar` is an array (or JSON string containing an array). The date field is `start`; effective attendance clock fields are `startTime` / `endTime`. `inDateTime` / `outDateTime` were empty in the verified tenant response and are **not** used. `isHoliday` / `isWeeklyOff` indicate non-workdays. `typeOfAwaitingApproval` indicates a pending request; `awaitingApproval` alone is a generic label even on ordinary rows and must not be mistaken for a pending flag.

Own-account read checks succeeded for November and October 2026: the calendar returned 30 and 31 daily records respectively. The verified response fields establish the processed calendar source. Raw-log absence or an unsuccessful raw-log read is not used to infer effective attendance or a holiday. No attendance submission, approval, regularization or other attendance write was invoked during research. No real password, session token, API key, cookie or private report response is committed.

The precheck remains a user rule: after 09:00 Bangkok, partial minutes round up, monthly total strictly above 30 highlighted. This is not a claim to reproduce every HR grace/payroll rule. The server's effective records are used; records with pending requests are excluded until settled. Calendar query/date ownership and duplicate rows are validated. Daily data never remains from a previously selected date.

## Local alarm behavior

At alarm time Android reads only local account/date presence and the cached calendar. It does not contact HONO or depend on an internet response. A successful IN or OUT, and successful history/calendar synchronization while the app is open, update the cache. An IN stops remaining morning alarms for today while leaving 18:00 OUT; OUT stops today's remaining OUT alarm. Each slot is then armed for the next eligible workday. Yesterday's or another account's records cannot suppress today.

An attendance event made through another application is not observable until this app synchronizes. Open/refresh it to sync. Unknown local state prompts a check rather than claiming a missing punch. Company working/non-working dates are cached when a month is viewed; unsynced months use the configured weekly workdays. Manual extra workdays and holidays override cached calendar dates.

Alarm style uses an Android alarm-category notification, alarm audio usage, a stop-sound action and a bounded 60-second notification timeout on supported Android versions. Full-screen presentation requires OS permission and may fall back to a heads-up notification. The app provides a clear clock popup when the alarm notification opens it. Login, saved credentials and attendance screens remain behind the device keyguard; the main activity does not globally show over a locked phone. Unlock to use the popup and attendance flow. Opening the attendance screen is an explicit action; neither the alarm nor dismissing it submits a punch. Android force-stop, OS power controls, denied permissions or shutdown can still prevent delivery.

The background alarm no longer retains or uses network access credentials. 1.1's retained read access is deleted during initialization; only an account identity and local date flags are needed. The login password remains governed by the separate remember-login setting. iOS keeps the bounded 14-day local schedule and last synced data; it does not pretend to support Android full-screen alarm behavior.

## History and packaging

History uses Thai short dates, 24-hour clock cards and a separate effective calendar summary. Original server text is available by expanding each raw punch card. The UI explicitly labels raw and processed sources.

APK delivery changes from debug to R8/resource-shrunk release, split per ABI. The retained test certificate and application ID remain unchanged for updates. Notification sounds/icon are explicitly kept for release resource shrinking. The physical-device package is ARM64; an x86_64 release is separately used for emulator startup. Actual size and runtime evidence are recorded after building; no arbitrary size target is promised.
