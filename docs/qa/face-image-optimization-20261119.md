# Face image comparison and optimization — 19 November 2026

## Reference check

The supplied HONO screenshot shows an actual face rectangle on a portrait camera image, a processing dialog and a separate employee picture. The modal dims the underlying preview. Its on-screen dimensions and darkness cannot establish the original uploaded image's resolution, JPEG quality, Azure confidence or API timing.

A local browser test ran the real bundled MediaPipe model on the camera region extracted into memory from that screenshot. It found one face, a suitable position, an acceptable frontal pose and both eyes open. No employee photo was sent to a provider, used to issue a proof, or submitted as attendance. The screenshot and extracted face are excluded from the repository.

This establishes that this reference frame clears our local positioning checks. It does not measure identity verification or demonstrate that a static photo can complete the fresh blink challenge.

## Changes

- Web guidance now follows the actual normalized face bounds. The overlay accounts for video letterboxing and horizontal mirroring. Rendering is limited to updates about every 180 ms, and bounds are hidden during verification. Guide/text pixels remain outside the submitted image.
- Native capture formerly encoded JPEG at quality 20 and bounded only width. It now bakes EXIF orientation, bounds the longest edge to 1280 without upscaling, starts at quality 92 with bounded size fallbacks, and prepares the image in an isolate. Its PNG is derived from the same verified JPEG. This changes native source code; this delivery does not produce or install a new Android/iOS binary.
- The web already used a bounded quality-92 JPEG. Its verify and submit JPEG bytes remain identical. The server now builds an opaque RGB PNG using Sub filtering and zlib level 3/default strategy, preserving every decoded pixel while reducing the HONO upload payload.
- Verify/submit logs now include per-stage elapsed times and numeric image dimensions/byte sizes. They contain no photos, employee IDs, face coordinates, provider confidence values or credentials. This separates decode, enrollment, provider detection/identification, attendance snapshot, PNG encoding and upload time.
- Provider identity checks, company thresholds, live capture prerequisites, signed image proofs and duplicate-attendance checks retain their existing behavior. There is no automatic retry of an uncertain attendance write.

## Reproducible encoding benchmark

Run `node scripts/benchmark-capture.mjs`. The fixture is a deterministic 960 × 1280 synthetic gradient/noise image, encoded to JPEG at quality 92. This measures local encoding, not provider recognition or end-to-end latency.

| Encoding | PNG bytes | Median local encoding time, 4 samples |
| --- | ---: | ---: |
| Previous PNG defaults | 2,770,494 | 313 ms |
| Optimized RGB PNG | 2,036,685 | 269 ms |

The fixture saves 733,809 bytes, approximately 26.5%, with identical decoded pixels. Results vary with image content and runtime load; compression is not guaranteed to shrink every possible image. No production speedup or facial recognition percentage is inferred from these numbers.

## Validation

- Flutter analyzer: no issues.
- Flutter tests: 109 passed, including native quality/detail, portrait EXIF correction, longest-edge sizing, identical JPEG/PNG pixels, mirrored face-overlay placement, compact-device insets, verification failure handling and existing UI/attendance regressions.
- Node tests: 39 passed, including pixel-identical PNG round trips, reduced size for the deterministic fixture, safe timing/image metadata, stale attendance state, proof and duplicate-write checks.
- Release web build: passed with Flutter 3.35.7.
- Chromium camera/API fixtures passed at 375 × 667, 375 × 553 with a 640 × 480 source, 390 × 844, 844 × 390 and 1366 × 768. Assertions cover the actual face bounds in the camera bridge, one blink cycle, retained captured photo, JPEG equality across poster/verify/submit and exactly one simulated verify and submit.

Live iPhone/Android cameras and HONO identity matching were not physically exercised. Recent runtime log queries supplied no matching events, and the project's retention rejected a 24-hour query, so prior verification failures cannot be diagnosed retrospectively from these logs. Future attempts can be correlated by request ID and stage timing.

## Provider guidance

Microsoft documents that input lighting, occlusion and expressions affect recognition, and that file size affects upload and service latency. This work keeps the original face appearance and treats the screenshot as a composition reference.

- https://learn.microsoft.com/en-us/azure/ai-services/face/concept-face-recognition
- https://learn.microsoft.com/en-us/azure/ai-services/face/how-to/mitigate-latency
