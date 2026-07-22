#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$BASE/lib/common.sh"

PROJECT="${1:-}"
[ -z "$PROJECT" ] && die "project path missing"

BUILD="$PROJECT/build"
APK="$BUILD/apk"
DEX="$BUILD/dex"
OUT="$PROJECT/out"

mkdir -p "$OUT"

BUILD_TYPE="${CANDY_BUILD_TYPE:-debug}"
APK_NAME="app-$BUILD_TYPE.apk"

require_cmd zip

[ -f "$APK/base.apk" ]        || die "base.apk not found — did the resources step run?"
[ -f "$DEX/classes.dex" ]     || die "classes.dex not found — did the DEX step run?"

log_info "Packaging APK ($BUILD_TYPE)..."

cp "$APK/base.apk" "$OUT/$APK_NAME"

# Stage everything that goes into the zip in one folder so paths inside
# the APK end up correct (classes.dex at the root, native libs under
# lib/, assets under assets/) rather than fighting `zip`'s flag quirks
# with several separate calls.
STAGE="$BUILD/package_stage"
rm -rf "$STAGE"
mkdir -p "$STAGE"

cp "$DEX"/classes*.dex "$STAGE/"

# `new.sh` creates assets/ and libs/ folders in every project, but the
# original package.sh never referenced either one — anything placed
# there silently never reached the final APK. Both are now included.
if [ -d "$PROJECT/assets" ] && [ -n "$(find "$PROJECT/assets" -mindepth 1 -print -quit 2>/dev/null)" ]; then
    log_info "Adding assets/..."
    cp -r "$PROJECT/assets" "$STAGE/"
fi

if [ -d "$PROJECT/libs" ] && [ -n "$(find "$PROJECT/libs" -mindepth 1 -print -quit 2>/dev/null)" ]; then
    log_info "Adding prebuilt native libraries from libs/ (as lib/)..."
    mkdir -p "$STAGE/lib"
    cp -r "$PROJECT/libs/." "$STAGE/lib/"
fi

NATIVE_LIBS="$BUILD/native_libs"
if [ -d "$NATIVE_LIBS" ] && [ -n "$(find "$NATIVE_LIBS" -mindepth 1 -print -quit 2>/dev/null)" ]; then
    log_info "Adding compiled C++ libraries from cpp/ (as lib/)..."
    mkdir -p "$STAGE/lib"
    cp -r "$NATIVE_LIBS/." "$STAGE/lib/"
fi

(cd "$STAGE" && zip -r -X "$OUT/$APK_NAME" . >/dev/null)

echo
log_ok "APK packaged: $OUT/$APK_NAME"
