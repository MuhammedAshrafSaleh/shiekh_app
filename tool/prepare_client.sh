#!/usr/bin/env bash
# tool/prepare_client.sh
#
# Stages a client's brand assets into the (git-ignored) locations Flutter bundles
# from. clients/<name>/ is the single source of truth; the staged copies are
# generated outputs and must stay git-ignored so running this never dirties
# `git status`.
#
# Usage: tool/prepare_client.sh <client>   e.g. tool/prepare_client.sh ahmed
set -euo pipefail

CLIENT="${1:-}"
if [[ -z "$CLIENT" ]]; then
  echo "usage: tool/prepare_client.sh <client>" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/clients/$CLIENT"

if [[ ! -d "$SRC" ]]; then
  echo "error: no client folder at clients/$CLIENT" >&2
  exit 1
fi

# Runtime Flutter asset (splash sheikh photo) — must exist on disk at build time.
cp "$SRC/sheikh.png" "$ROOT/assets/images/sheikh.png"
# Launcher-icon source consumed by flutter_launcher_icons.
cp "$SRC/icon.png" "$ROOT/assets/app-icon.png"

# Native (cold-start) splash artwork — gold-ring circular avatar matching the
# Flutter SplashPage, sized for the Android 12+ safe circle. Consumed by
# flutter_native_splash (image: / android_12.image:). Regenerate per client so
# `flutter_native_splash:create` bakes the right sheikh into the native layer.
dart run "$ROOT/tool/gen_native_splash.dart" "$CLIENT"

echo "Staged brand assets for '$CLIENT'."
echo "  assets/images/sheikh.png            <- clients/$CLIENT/sheikh.png"
echo "  assets/app-icon.png                 <- clients/$CLIENT/icon.png"
echo "  assets/generated/native_splash.png  <- generated from clients/$CLIENT/sheikh.png"
echo
echo "Next: bake the native splash into android resources:"
if [[ "$CLIENT" == "ahmed" ]]; then
  echo "  dart run flutter_native_splash:create"
else
  echo "  dart run flutter_native_splash:create --flavor $CLIENT"
fi
