# Attendance history, late minutes and reminders — 1.1

## History correctness

Changing the selected date immediately clears rows, state and errors. Each read carries a date/session/request generation; an earlier response cannot overwrite the new selection. Today-only attendance state is not requested for historical dates. Empty successful lists and explicit no-record messages are displayed as empty history; ambiguous denial, expired session and permissions remain errors. An empty list is never evidence of a company holiday.

## Lateness precheck

The report is explicitly monthly and read-only. For configured workdays through today, use the earliest valid IN in Bangkok wall time. Exactly 09:00 is on time; later timestamps count as late, with fractional minutes rounded up. A total of exactly 30 minutes is below the **over 30** warning condition. The report never issues HR warning letters. Missing INs and unparseable/failed days are shown separately; the total is only the minutes established from readable records.

Supported server formats include HONO legacy `06-Nov-2026----  9:05am`, unzoned date/time or time-only clocks, and zoned ISO timestamps converted to Bangkok. Date mismatches are rejected rather than assigned to the selected day.

## Calendar and alerts

The app does not yet claim to synchronize HONO holiday/leave calendars. Existing reverse-engineering metadata mentions calendar functions but does not establish the request and response contract. Configure weekly workdays, company holidays and extra workdays in the bell screen; Monday–Friday is the initial default. Extra workdays override holidays. Personal leave must also be added manually when it should suppress reminders.

Alerts are opt-in: 08:20, 08:30, 08:50 for IN; 18:00 for OUT, Bangkok time. Android retains a read-only session in OS secure storage when enabled and queries own-account history at the alarm. Confirmed punches suppress matching alerts; network/session failure is an explicitly unknown status, optionally suppressible. Notifications only open the app: they never capture a face or submit attendance. Sound choices include system, two bundled original tones, silent, and Android's notification sound picker.

Android exact-alarm access is optional: without it alerts are approximate. Force-stop, device shutdown, Doze/OEM battery management and revoked notification permission can prevent or delay delivery. Alarms more than 15 minutes late are skipped rather than showing a stale reminder. This needs physical-device verification, including reboot and battery controls.

iOS uses scheduled local notifications and the last synchronized history; it cannot promise a fresh HONO read while closed. Opening/resuming the app refreshes today's history and cancels applicable reminders. Up to 14 days are scheduled at a time (56 slots maximum); open the app to extend the schedule. A punch made from another client cannot cancel an already scheduled iOS alert until the app synchronizes.

## Device acceptance checks

- Load Nov 6, switch to Nov 7; verify no Nov 6 row remains while pending, on empty response, or on failure. Switch dates rapidly to exercise delayed replies.
- Check legacy 09:00am, 09:00:01am, 09:30am and totals 30/31 minutes. Compare to HONO records and confirm the company's actual HR calculation policy.
- Enter company holidays and working Saturdays; confirm suppressed/enabled alert dates.
- Grant notifications, test every sound, then enable reminders. Inspect exact-alarm settings on Android. Verify next scheduled slot with the app closed and device locked; test a prior IN/OUT, no network, expired session, reboot and logout.
- On iOS, compare a punch from another app before and after opening this app; the latter sync should cancel the relevant pending slots.

Development validation uses synthetic records and offline UI fixtures. No live attendance writes are made by test tools. Physical biometric and real tenant attendance acceptance remain account-owner UAT.
