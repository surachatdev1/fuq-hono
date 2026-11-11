#!/usr/bin/env bash
set -euo pipefail
# Avoid cloud metadata autodetection and analytics in build environments.
export CI=true FLUTTER_SUPPRESS_ANALYTICS=true
# CI may supply Flutter on PATH; Vercel downloads the same pinned SDK.
if ! command -v flutter >/dev/null 2>&1; then
  TASK_FLUTTER_ROOT="${TMPDIR:-/tmp}/nwl-flutter-3.35.7"
  if [ ! -x "$TASK_FLUTTER_ROOT/flutter/bin/flutter" ]; then
    mkdir -p "$TASK_FLUTTER_ROOT"
    git clone --depth 1 --branch 3.35.7 https://github.com/flutter/flutter.git "$TASK_FLUTTER_ROOT/flutter"
    test "$(git -C "$TASK_FLUTTER_ROOT/flutter" rev-parse HEAD)" = "adc901062556672b4138e18a4dc62a4be8f4b3c2"
  fi
  export PATH="$TASK_FLUTTER_ROOT/flutter/bin:$PATH"
fi
flutter config --enable-web
flutter pub get
cinematic="${NWL_CINEMATIC:-false}"
if [[ "${VERCEL_ENV:-}" == preview && -z "${NWL_CINEMATIC:-}" ]]; then
  cinematic=true
fi
flutter build web --release --no-web-resources-cdn --pwa-strategy=none \
  --dart-define="NWL_CINEMATIC=$cinematic"
if [[ "$cinematic" == true ]]; then
  sed -i 's/<body>/<body class="cinematic">/' build/web/index.html
fi
mkdir -p build/web/vision build/web/icons
cp node_modules/@mediapipe/tasks-vision/vision_bundle.mjs build/web/vision/
cp -R node_modules/@mediapipe/tasks-vision/wasm build/web/vision/
cp assets/brand.png build/web/icons/brand.png
curl --fail --location --retry 2 'https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task' -o build/web/vision/face_landmarker.task
# Do not publish protocol material in web assets. The browser has only a local stub.
rm -f build/web/assets/assets/hono_client_protocol.json
printf '%s' '{"protocol_version":"hono-22.9-323","key":"0000000000000000","iv":"0000000000000000","bootstrap_key":"web"}' > build/web/assets/assets/hono_client_protocol.json
