#!/usr/bin/env bash
set -euo pipefail

POWERX_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE_DIR="${COLLABORA_SOURCE_DIR:-$POWERX_ROOT/.engine/collabora-online}"
AAR_SOURCE="${COLLABORA_ANDROID_AAR:-$SOURCE_DIR/android/lib/build/outputs/aar/lib-release.aar}"
MODULE_DIR="$POWERX_ROOT/example/android/office_engine"
LIBS_DIR="$MODULE_DIR/libs"
DEST_AAR="$LIBS_DIR/collabora-office-engine.aar"

if [[ ! -f "$AAR_SOURCE" ]]; then
  cat >&2 <<MSG
Collabora Android AAR was not found:
  $AAR_SOURCE

Build it first with:
  tool/office_engine/build_collabora_android.sh

Or point to a prebuilt AAR:
  COLLABORA_ANDROID_AAR=/path/to/lib-release.aar $0
MSG
  exit 2
fi

mkdir -p "$LIBS_DIR"
cp "$AAR_SOURCE" "$DEST_AAR"

echo "Packaged Collabora Office Engine AAR:"
echo "  $DEST_AAR"
