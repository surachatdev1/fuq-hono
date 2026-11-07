# NWL Secret Login — Flutter

One Dart application for Android and iOS. Migrates the existing NWL 0.5 native flow into Flutter: login, own-account attendance/history, saved Google Maps pins, front-camera fresh blink, configured anti-spoof and Azure identity verification, automatic single attendance submission, and explicit fresh scan after errors.

## Run and build

Pinned toolchain: Flutter 3.35.7 / Dart 3.9. Android minimum API 23; iOS minimum 15.5. `flutter pub get`, then `flutter run`.

```sh
flutter analyze
flutter test --update-goldens
flutter build apk --debug
# On macOS with Xcode and CocoaPods:
flutter build ios --release --no-codesign
# After configuring an Apple development team and distribution signing:
flutter build ipa
```

CI builds Android debug APKs (universal for emulator tests and smaller ARM64 for physical phones) and an unsigned iOS device app. The unsigned iOS archive is NOT an installable IPA. Configure an Apple team and provisioning profile in `ios/Runner.xcworkspace` for device installation/TestFlight. The dedicated test signing key is cached at .ci/debug.keystore and backed up as a PRIVATE build artifact; retain its private backup to preserve updates after cache eviction. CI compares its public certificate to docs/test-signing.sha256 and fails rather than silently changing the key. Restore the retained PRIVATE backup to .ci/debug.keystore when needed; the key itself is never committed. It is not a production release key. The Flutter Android app has a new application ID and can coexist with the old Kotlin APK; old private preferences/passwords are not transferred automatically.

## History, lateness and reminders (1.1)

History clears immediately on date changes and ignores stale replies. Read-only monthly lateness uses the first IN after 09:00 Bangkok, rounds partial minutes up, and highlights strictly over 30 minutes; missing/unreadable days remain incomplete. The bell screen configures opt-in 08:20/08:30/08:50 IN reminders and an 18:00 OUT reminder, sound selection, weekly workdays, holidays and extra workdays. Company holidays/leave are currently entered manually, not synchronized from HONO. Android checks latest own-account history at the alarm when online; iOS uses the last synced snapshot and a 14-day rolling local schedule. See [behavior and device acceptance checks](docs/attendance-1.1.md).

## Design

Preserves the chosen five-screen NWL board: midnight navy, mint primary action, restrained lavender accent, generous spacing, large readable Thai type and a clear camera/status hierarchy. Refined through principles of restraint, material clarity and functional hierarchy associated with premium industrial design. No affiliation with B&O, Red Dot or Awwwards and no claim of award certification. Noto Sans Thai is bundled locally; license is in assets/FONT-LICENSE.txt. Existing NWL monogram is reused; template launcher icons are replaced.

## Runtime contract

- Shared Dart HONO 22.9 bootstrap, dynamic keys, credential authentication, history, state, own-person enrollment, configured spoof check, Azure detect/identify and multipart writer. Legacy wire envelope remains `type=android` on both OSs for compatibility with the proven Android API; iOS tenant acceptance needs device UAT.
- Credentials use OS secure storage only when requested. Photos and face-provider keys are never persisted or logged. Opt-in attendance reminders retain only read access (session token, own employee, tenant and history API key) in OS secure storage; confirmed daily IN/OUT snapshots are stored locally per account/date. Disabling reminders deletes retained access; logout also cancels notifications and alarms. A generated installation identifier substitutes for IMEI; no installed HONO dependency. MFA/SSO/password-reset/terms flows fail closed and direct users to the official app.
- Saved Maps links resolve only allowlisted HTTPS Google hosts; redirects are validated at every hop, no auth headers. A viewport center requires explicit acknowledgement. UI labels locations as selected pins rather than measured phone GPS.
- Fresh open→closed→open blink with one face is only a capture prerequisite. Configured spoof validation and identity verification are mandatory. Strict own-person and company confidence thresholds apply; presence detection never counts as identity match.
- Capture→verification→fresh state/history→one POST. No automatic network retries. Pausing before the writer blocks submission and requires a new scan. A pending network POST may complete after app backgrounding; unknown results lock scanning until fresh successful history/state and explicit acknowledgement.
- There is no timestamp field in the proven legacy writer; server supplies attendance time. Historical date selection is read-only; new punches are allowed only for today in Bangkok time. A recorded IN/OUT leaves OUT available, including deliberate manual repeat-OUT tests; server acceptance remains authoritative.
- Demo and screenshot fixtures do not call attendance APIs or claim biometric success.

## Verification limits

CI tests use synthetic protocol responses and offline rendering. No real user password is embedded and development tools do not post live attendance. Physical-device camera orientation/permissions, fresh-face verification and actual tenant writes need account-owner UAT on each platform. See design-qa.md for rendered review and CI status.

## Verified delivery

Version 1.1.0+2: [build run 42327599041](https://github.com/surachatdev1/fuq-hono/actions/runs/42327599041) passes strict analysis and 33 tests, and compiles Android universal/ARM64 debug APKs plus an unsigned iOS release app. See docs/qa/1.1-verification.md for final native startup evidence and device acceptance limits. CI-generated formatted Dart source and the resolved lockfile are retained in the repository.

The distributed ARM64 debug APK is 187,159,717 bytes. Its APK v2 signer certificate matches the retained Flutter 1.0 test identity. Physical notification timing, OS permissions/sounds, camera/face and real tenant acceptance still require device UAT. No live attendance was posted by development tools.
