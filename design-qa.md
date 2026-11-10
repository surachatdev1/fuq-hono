# Flutter design verification — 1.0.0

Source visual: selected five-screen NWL board, Library libfile_704d101e3ac081918a8dcfd4195bbfd9; local /workspace/scratch/3a19da679a50/generated_images/exec-f1b7b012-b808-4922-a383-47957f8dc0eb.png (1881×836). The existing native 0.5 app supplies the behavior/design baseline. This is an explicitly requested Flutter Android/iOS application, not a browser prototype.

## Capture method and normalization

Flutter engine render captures at 390×844 logical/physical pixels, pixel ratio 1.0. Noto Sans Thai, Noto Sans Latin and MaterialIcons fonts are loaded explicitly for engine tests. Source board panels are approximately 340×654; compare app-owned content at normalized width 340, preserving aspect ratio rather than distorting the taller implementation. Fixtures display UI PREVIEW in place of the live camera content, never the concept portrait as an identity asset.

## Review history

Initial evidence /tmp/fuq-ui-v1/compare-{splash,login,today,clock-in,clock-out}.png exposed P1 missing Latin/icon fonts in the render harness. Added bundled Latin fallback and explicit icon-font loading; fixed harness localization/debug-banner mismatch and used the actual HomePage for Today captures.

Revised evidence /tmp/fuq-ui-final/compare-{splash,login,today,clock-in,clock-out}.png confirms fonts and icons. P2 Today issues: unsupported text arrow glyphs and two equally prominent actions. Replaced text arrows with Material chevrons, moved IN/OUT choice into a segmented selector and retained one primary scan button. Also made the summary date match Thai Buddhist-era copy and kept brand subtitle weight explicit. Final current render evidence is committed under docs/qa/compare-{splash,login,today,clock-in,clock-out}.png; input captures /tmp/fuq-ui-reviewed/*.png, CI artifact 13545499067 (run 42306466850). All five pairs were opened together with their reference panels. The Today chevrons, Thai date and one-primary-action selector are confirmed. Focused comparison docs/qa/focus-login-controls.png was inspected for field labels, password control, remember control and primary button typography. No actionable P0/P1/P2 visual finding remains.

## Required surfaces

Typography: bundled local Thai/Latin families, readable labels and headings; narrow 320×640 at 130% scale tested for scroll access. Spacing: 24 px page insets, consistent field gaps, bounded camera viewport and 64 px primary action. Colors: midnight navy/mint/lavender, amber failures; flat surfaces intentionally refine the subtle concept gradients. Assets: existing monogram reused, template launcher icons replaced; native OS chrome is runtime-owned. Copy: real data only, empty demo records, selected-pin provenance, identity-match status only after remote verification, explicit retry and no fake success.

## Remaining verification

Final build run 42308940668 (source d60679219e4bc822eadce11b962fba8f71f1fb90): Android and iOS build jobs and native Android capture job all succeeded. Strict analyzer: no issues. Tests: 21 passed. Signing cache v2 was saved at the explicit .ci path; the APK certificate matches the retained private backup. Final source formatting/lint fixes and dependency lock are taken from its validated source artifact 13547797413.

Final installed-native evidence: artifact 13548636070, /tmp/fuq-native-final/{01-native-login,02-native-stable}.png and runtime-errors.txt (empty). Emulator API 35 / Pixel 7, physical 1080×2400, approximately 411 dp wide at 420 dpi. docs/qa/compare-native-login.png normalizes app content after a 104 px top / 63 px bottom system crop to width 340 without changing aspect ratio; it confirms readable native type, fields, remember control, icon assets and primary action. Initial capture may show startup initialization; the stable capture reaches Login. No browser rendering is claimed or required for the requested native Flutter runtime.

An earlier UIAutomator-only navigation harness failed to obtain an idle XML tree before saving any screenshot. That harness result was rejected as startup evidence. The corrected native capture saves device pixels first, verifies process/window survival, records optional accessibility output and checks runtime errors; it is paired with actual Flutter widget navigation tests. This is a harness correction, not an unproven claim of a source startup crash fix. Camera permissions/orientation, actual fresh identity verification and attendance writes need physical-device UAT on both platforms. No live attendance request was sent by development tools.

## Final assessment

No actionable P0/P1/P2 remains in the reviewed visual states. All five engine render pairs and the installed Android Login were inspected with the source. Login controls received an enlarged focused comparison. Remaining P3 differences are deliberate flat native surfaces, adaptive spacing on a taller screen, and runtime camera content rather than the concept portrait. Demo empty records and multiple-action selection differ honestly from the fictional sample attendance in the reference.

Implementation checklist completed: local fonts/icons; existing logo; single primary action; Thai date; large-text scroll access; automatic verified-send presentation; explicit error retry; native startup; strict analysis/tests; platform builds. Camera orientation/permissions and real server authentication/attendance still need physical-device UAT and are not claimed as completed testing.

final result: passed

## Modern Flat UI — 10 November 2026

The shared production theme follows the supplied connected-poster reference:
#070F24 navy canvas, #111C34 navy surfaces, #F4F7FF text, #E0FFB4 lime
primary actions, #8BA2FF secondary accents and #FF8378 errors. Muted text is
#A5B2CA. The decorative flat clock uses a cobalt tile; the approved login
animation retains its lime, cobalt and coral artwork. Navigation, dialogs,
segmented controls and inputs share the palette, with no raised card shadows
or surface tints. Cards use 16 px corners and primary controls use 12 px corners.
Thai headings retain normal letter spacing. The login form is centered in a
bounded, scrollable card; small screens retain keyboard dismissal by dragging.
Web loading and standalone app chrome use the same navy palette.

Validation for this revision is recorded after the checks below; historical
native-device results above do not constitute native testing of this revision.

- `flutter analyze`: no issues found.
- `flutter test --no-pub`: 66 passing tests, including responsive shells and login
  at 320, 390, 768, 1024 and 1440 px, and updated visual baselines.
- `npm test`: 13 passing API contract tests.
- Inspected the regenerated 390×844 login, today and history captures at full size.
  Disabled primary-button icons now use the same subdued treatment as their labels.
- This UI revision was checked with demo fixtures; no live attendance was submitted.
