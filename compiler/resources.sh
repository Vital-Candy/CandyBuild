#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$BASE/lib/common.sh"
# shellcheck source=/dev/null
source "$BASE/lib/toml.sh"
# shellcheck source=/dev/null
source "$BASE/lib/sdk.sh"

PROJECT="${1:-}"
[ -z "$PROJECT" ] && die "project path missing"

BUILD="$PROJECT/build"
COMPILED="$BUILD/compiled"
GENERATED="$BUILD/generated"
APK="$BUILD/apk"

mkdir -p "$COMPILED" "$GENERATED" "$APK"

require_cmd aapt2

TARGET_SDK="$(toml_get "$PROJECT/Candy.toml" target_sdk 34)"

ANDROID_JAR="$(resolve_android_jar "$TARGET_SDK")" \
    || die "android.jar not found for API $TARGET_SDK. Set ANDROID_HOME or see docs/SDK.md"

log_info "aapt2: $(command -v aapt2)"
log_info "android.jar: $ANDROID_JAR"

# Collect compiled resources safely (handles spaces in paths) instead of
# an unquoted $(...) word-split, and — the actual functional bug fixed
# here — actually feed them into `aapt2 link` below. In the original
# script they were compiled into $COMPILED/ and never referenced again,
# so res/values, layouts etc. never made it into the APK.
DEP_FLATS=()
DEPS_RES="$BUILD/deps/res"
if [ -d "$DEPS_RES" ]; then
    for libres in "$DEPS_RES"/*/res; do
        [ -d "$libres" ] || continue
        libname="$(basename "$(dirname "$libres")")"
        libcompiled="$COMPILED/_deps/$libname"
        mkdir -p "$libcompiled"
        log_info "Compiling resources from dependency: $libname"
        aapt2 compile --dir "$libres" -o "$libcompiled/"
        while IFS= read -r -d '' f; do
            DEP_FLATS+=("$f")
        done < <(find "$libcompiled" -name "*.flat" -print0)
    done
fi

COMPILED_FLATS=()

if [ -d "$PROJECT/res" ]; then
    log_info "Compiling resources..."
    aapt2 compile --dir "$PROJECT/res" -o "$COMPILED/"

    while IFS= read -r -d '' f; do
        COMPILED_FLATS+=("$f")
    done < <(find "$COMPILED" -maxdepth 1 -name "*.flat" -print0)
else
    log_warn "No res/ folder found, skipping resource compilation"
fi

log_info "Linking resources..."

# --auto-add-overlay: if the app defines a resource with the same name as
# a dependency (e.g. re-declaring a color), the app's own value wins
# instead of aapt2 hard-failing on the clash. Dependency flats are listed
# first, the project's own last, for that overlay order to apply.
aapt2 link \
    -o "$APK/base.apk" \
    -I "$ANDROID_JAR" \
    --auto-add-overlay \
    --manifest "$PROJECT/AndroidManifest.xml" \
    --java "$GENERATED" \
    "${DEP_FLATS[@]}" \
    "${COMPILED_FLATS[@]}"

echo
log_ok "Resources OK"
echo "Generated: $GENERATED"
