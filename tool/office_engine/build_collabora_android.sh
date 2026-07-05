#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
  cat >&2 <<'MSG'
Collabora's native Android engine build currently needs Linux.

Run this script on a Linux machine/VM/CI runner with Android SDK + NDK installed,
then copy the produced artifacts back with package_collabora_android.sh.
MSG
  exit 2
fi

SOURCE_DIR="${COLLABORA_SOURCE_DIR:-$PWD/.engine/collabora-online}"
ANDROID_SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Android/Sdk}}"
ANDROID_NDK="${ANDROID_NDK_ROOT:-$ANDROID_SDK/ndk/23.0.7599858}"
ABI="${COLLABORA_ANDROID_ABI:-arm64-v8a}"
PARALLELISM="${COLLABORA_PARALLELISM:-$(getconf _NPROCESSORS_ONLN)}"

case "$ABI" in
  arm64-v8a) DISTRO="CPAndroidAarch64" ;;
  armeabi-v7a) DISTRO="CPAndroid" ;;
  x86_64) DISTRO="CPAndroidX86_64" ;;
  x86) DISTRO="CPAndroidX86" ;;
  *)
    echo "Unsupported ABI: $ABI" >&2
    exit 2
    ;;
esac

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "Collabora source directory does not exist: $SOURCE_DIR" >&2
  echo "Run tool/office_engine/fetch_collabora_source.sh first." >&2
  exit 2
fi

ENGINE_DIR="$SOURCE_DIR/engine"
if [[ ! -d "$ENGINE_DIR" ]]; then
  cat >&2 <<MSG
This checkout does not contain an engine/ directory.

Current Collabora docs describe a monorepo with engine/ inside the source tree.
Older/stable branches may require a separate LibreOffice/Collabora core build.
Set COLLABORA_LO_BUILDDIR to that built engine/core directory and rerun:

  COLLABORA_LO_BUILDDIR=/path/to/built/libreoffice/core $0
MSG
  if [[ -z "${COLLABORA_LO_BUILDDIR:-}" ]]; then
    exit 2
  fi
else
  cat > "$ENGINE_DIR/autogen.input" <<EOF
--build=x86_64-unknown-linux-gnu
--with-android-ndk=$ANDROID_NDK
--with-android-sdk=$ANDROID_SDK
--with-distro=$DISTRO
--with-parallelism=$PARALLELISM
EOF

  (
    cd "$ENGINE_DIR"
    ./autogen.sh
    make -j "$PARALLELISM"
  )
  COLLABORA_LO_BUILDDIR="$ENGINE_DIR"
fi

(
  cd "$SOURCE_DIR"
  ./autogen.sh
  ./configure \
    --enable-androidapp \
    --with-lo-builddir="$COLLABORA_LO_BUILDDIR" \
    --with-android-abi="$ABI"
  make -j "$PARALLELISM"
)

(
  cd "$SOURCE_DIR/android"
  ./gradlew :lib:assembleRelease
)

echo
echo "Collabora Android library build finished."
echo "Expected AAR: $SOURCE_DIR/android/lib/build/outputs/aar/lib-release.aar"
