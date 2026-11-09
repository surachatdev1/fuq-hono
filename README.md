# NWL Secret Login — Flutter

One Dart application for Android, iOS and responsive Web. Migrates the existing NWL 0.5 native flow into Flutter: login, own-account attendance/history, saved Google Maps pins, front-camera fresh blink, configured anti-spoof and Azure identity verification, automatic single attendance submission, and explicit fresh scan after errors.

## Responsive Web

Deployed UI/demo: https://fuq-hono-rakadee.vercel.app/ . Login/real clocking require server environment configuration before use: SESSION_SECRET and a dedicated Upstash Redis ledger. The current Vercel connector cannot create those variables/storage (HTTP 403). No real attendance writes were made during development.

The web frontend uses the same Flutter screens with responsive navigation, a browser camera and a same-origin Node API. Browser passwords are not saved in localStorage. Web reminders only work while the page remains open and cannot replace exact native alarms. See [web setup, architecture and limitations](docs/web-deployment.md).

## Run and build

Pinned toolchain: Flutter 3.35.7 / Dart 3.9. Android minimum API 23; iOS minimum 15.5. `flutter pub get`, then `flutter run`.

```sh
flutter analyze
flutter test --update-goldens
flutter build apk --release --split-per-abi
# On macOS with Xcode and CocoaPods:
flutter build ios --release --no-codesign
# After configuring an Apple development team and distribution signing:
flutter build ipa
```

CI builds optimized Android release APKs per ABI (ARM64 for physical phones and x86_64 for emulator tests) and an unsigned iOS device app. The unsigned iOS archive is NOT an installable IPA. Configure an Apple team and provisioning profile in `ios/Runner.xcworkspace` for device installation/TestFlight. The dedicated test signing key is cached at .ci/debug.keystore and backed up as a PRIVATE build artifact; retain its private backup to preserve updates after cache eviction. CI compares its public certificate to docs/test-signing.sha256 and fails rather than silently changing the key. Restore the retained PRIVATE backup to .ci/debug.keystore when needed; the key itself is never committed. It is not a production release key. The Flutter Android app has a new application ID and can coexist with the old Kotlin APK; old private preferences/passwords are not transferred automatically.

## History, lateness and local alarms (1.2)

Monthly lateness uses the effective `startTime` from HONO's processed attendance calendar (`CalendarMaster/showCalendar_v2`), not raw punch timestamps. Raw punches are shown separately as readable 24-hour clock cards with expandable original text. Missing/pending processed data cannot fall back to raw time. The precheck highlights strictly over 30 monthly late minutes after 09:00 Bangkok, with partial minutes rounded up.

At 08:20/08:30/08:50 and 18:00 Android checks cached account/date attendance flags and calendar dates locally, without any API call. Confirmed IN skips today's remaining morning slots, preserving OUT; confirmed OUT stops today's OUT reminder. Alarms move to the next eligible workday. Android alarm style includes a stop-sound action, 60-second timeout on supported OS versions, and an app popup; full-screen presentation depends on OS permission. iOS retains a 14-day local schedule using last synced information.

If attendance is recorded through another app, open/refresh this app to synchronize it. Calendar working/holiday dates are cached for viewed months, with manual overrides and weekly defaults for months not synced. Alarm dismissals do not create attendance. See [verified source, behavior and limits](docs/attendance-1.2.md).

## Design

Preserves the chosen five-screen NWL board: midnight navy, mint primary action, restrained lavender accent, generous spacing, large readable Thai type and a clear camera/status hierarchy. Refined through principles of restraint, material clarity and functional hierarchy associated with premium industrial design. No affiliation with B&O, Red Dot or Awwwards and no claim of award certification. Noto Sans Thai is bundled locally; license is in assets/FONT-LICENSE.txt. Existing NWL monogram is reused; template launcher icons are replaced.

## Runtime contract

- Shared Dart HONO 22.9 bootstrap, dynamic keys, credential authentication, history, state, own-person enrollment, configured spoof check, Azure detect/identify and multipart writer. Legacy wire envelope remains `type=android` on both OSs for compatibility with the proven Android API; iOS tenant acceptance needs device UAT.
- Credentials use OS secure storage only when requested. Photos and face-provider keys are never persisted or logged. Alarms retain only account identity and confirmed daily IN/OUT flags locally per account/date; no session token or API key is needed for alarms. Version 1.1 retained read access is deleted on initialization. Logout cancels notifications and alarms. A generated installation identifier substitutes for IMEI; no installed HONO dependency. MFA/SSO/password-reset/terms flows fail closed and direct users to the official app.
- Saved Maps links resolve only allowlisted HTTPS Google hosts; redirects are validated at every hop, no auth headers. A viewport center requires explicit acknowledgement. UI labels locations as selected pins rather than measured phone GPS.
- Fresh open→closed→open blink with one face is only a capture prerequisite. Configured spoof validation and identity verification are mandatory. Strict own-person and company confidence thresholds apply; presence detection never counts as identity match.
- Capture→verification→fresh state/history→one POST. No automatic network retries. Pausing before the writer blocks submission and requires a new scan. A pending network POST may complete after app backgrounding; unknown results lock scanning until fresh successful history/state and explicit acknowledgement.
- There is no timestamp field in the proven legacy writer; server supplies attendance time. Historical date selection is read-only; new punches are allowed only for today in Bangkok time. A recorded IN/OUT leaves OUT available, including deliberate manual repeat-OUT tests; server acceptance remains authoritative.
- Demo and screenshot fixtures do not call attendance APIs or claim biometric success.

## Verification limits

CI tests use synthetic protocol responses and offline rendering. No real user password is embedded and development tools do not post live attendance. Physical-device camera orientation/permissions, fresh-face verification and actual tenant writes need account-owner UAT on each platform. See design-qa.md for rendered review and CI status.

## Verified delivery

Version 1.2.0+3: strict analysis and 41 tests pass; ARM64/x86_64 Android release and unsigned iOS builds pass. The delivered ARM64 APK is 34.7 MB, down 81.5% from 1.1. Full delivery evidence is in docs/qa/1.2-verification.md. CI-generated formatted Dart source and resolved lockfile are retained in the repository.

The application ID and retained Flutter test signing certificate remain the same for updates. This is a privately distributed test-signed release build, not Play Store production signing. Physical notification timing, permissions/sound audibility, camera/face and actual tenant acceptance still require device UAT. Development tools performed authorized own-account login/calendar/history reads to establish the effective-time contract and did not submit attendance.
