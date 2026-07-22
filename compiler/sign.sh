#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$BASE/lib/common.sh"

PROJECT="${1:-}"
[ -z "$PROJECT" ] && die "project path missing"

OUT="$PROJECT/out"
BUILD_TYPE="${CANDY_BUILD_TYPE:-debug}"
APK_NAME="app-$BUILD_TYPE.apk"
APK="$OUT/$APK_NAME"

[ -f "$APK" ] || die "APK not found: $APK"

require_cmd apksigner

if [ "$BUILD_TYPE" = "release" ]; then
    KEYSTORE="${CANDY_KEYSTORE:-}"
    KS_PASS="${CANDY_KEYSTORE_PASS:-}"
    KEY_ALIAS="${CANDY_KEY_ALIAS:-}"
    KEY_PASS="${CANDY_KEY_PASS:-$KS_PASS}"

    [ -z "$KEYSTORE" ]  && die "Release build needs CANDY_KEYSTORE (path to your keystore). See docs/SDK.md"
    [ -f "$KEYSTORE" ]  || die "Keystore not found: $KEYSTORE"
    [ -z "$KS_PASS" ]   && die "Release build needs CANDY_KEYSTORE_PASS"
    [ -z "$KEY_ALIAS" ] && die "Release build needs CANDY_KEY_ALIAS"

    log_info "Signing release build with $KEYSTORE..."

    apksigner sign \
        --ks "$KEYSTORE" \
        --ks-pass "pass:$KS_PASS" \
        --ks-key-alias "$KEY_ALIAS" \
        --key-pass "pass:$KEY_PASS" \
        "$APK"
else
    # Kept under CandyBuild's own home rather than ~/.android/debug.keystore
    # so this tool never overwrites a real Android Studio debug keystore
    # a user might also have on the same machine.
    KEYSTORE="$HOME/.candybuild/debug.keystore"

    if [ ! -f "$KEYSTORE" ]; then
        log_info "Creating debug keystore..."
        mkdir -p "$(dirname "$KEYSTORE")"
        keytool -genkeypair -v \
            -keystore "$KEYSTORE" \
            -storepass android \
            -alias androiddebugkey \
            -keypass android \
            -keyalg RSA \
            -keysize 2048 \
            -validity 10000 \
            -dname "CN=Android Debug,O=Android,C=US" >/dev/null 2>&1
    fi

    log_info "Signing debug build..."

    apksigner sign \
        --ks "$KEYSTORE" \
        --ks-pass pass:android \
        --key-pass pass:android \
        "$APK"
fi

log_ok "Signed: $APK"
