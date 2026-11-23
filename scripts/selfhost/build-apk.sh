#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

[[ -f .app.env ]] || { echo "Missing .app.env. Copy .app.env.example and set your public URLs." >&2; exit 1; }
set -a
. ./.app.env
set +a

: "${PB_URL:?Set PB_URL in .app.env}"
: "${CENTRIFUGO_WS:?Set CENTRIFUGO_WS in .app.env}"
case "$PB_URL" in https://*) ;; *) echo "PB_URL must start with https://" >&2; exit 1 ;; esac
case "$CENTRIFUGO_WS" in wss://*) ;; *) echo "CENTRIFUGO_WS must start with wss://" >&2; exit 1 ;; esac
if [[ "$PB_URL" == *"YOUR-CODESPACE"* || "$CENTRIFUGO_WS" == *"YOUR-CODESPACE"* ]]; then
  echo "Replace the YOUR-CODESPACE placeholders in .app.env with the actual Codespaces forwarded URLs." >&2
  exit 1
fi
if [[ "$PB_URL" == *"togetherly.day"* || "$CENTRIFUGO_WS" == *"togetherly.day"* ]]; then
  echo "Refusing to build against the upstream author's togetherly.day backend. Set your own endpoints." >&2
  exit 1
fi

args=(build apk --release
  "--dart-define=PB_URL=${PB_URL%/}"
  "--dart-define=CENTRIFUGO_WS=$CENTRIFUGO_WS")
[[ -n "${KINOPOISK_TOKEN:-}" ]] && args+=("--dart-define=KINOPOISK_TOKEN=$KINOPOISK_TOKEN")
[[ -n "${STORE:-}" ]] && args+=("--dart-define=STORE=$STORE")

# The app's source tree is mounted into the builder; no Flutter SDK installation is needed on the host.
docker run --rm \
  --user "$(id -u):$(id -g)" \
  -e HOME=/tmp/flutter-home \
  -v "$ROOT:/workspace" \
  -w /workspace \
  ghcr.io/cirruslabs/flutter:stable \
  sh -lc 'flutter pub get && exec flutter "$@"' sh "${args[@]}"

echo "APK output: build/app/outputs/flutter-apk/app-release.apk"
