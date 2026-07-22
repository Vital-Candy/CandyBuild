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
OBJ="$BUILD/obj"
DEX="$BUILD/dex"

mkdir -p "$DEX"

[ -d "$OBJ" ] || die "Compiled classes not found — did the Kotlin step run?"

require_cmd d8

# Previously this hardcoded ".../platforms/android-36/android.jar" while
# resources.sh and kotlin.sh searched dynamically — a project targeting
# any other SDK level, or a machine without exactly android-36 installed,
# would fail here even though the earlier steps succeeded.
TARGET_SDK="$(toml_get "$PROJECT/Candy.toml" target_sdk 34)"
MIN_SDK="$(toml_get "$PROJECT/Candy.toml" min_sdk 26)"
ANDROID_JAR="$(resolve_android_jar "$TARGET_SDK")" \
    || die "android.jar not found for API $TARGET_SDK. Set ANDROID_HOME or see docs/SDK.md"

log_info "Creating DEX (min-api $MIN_SDK)..."

CLASS_FILES=()
while IFS= read -r -d '' f; do
    CLASS_FILES+=("$f")
done < <(find "$OBJ" -name "*.class" -print0)

DEPS_CLASSES="$BUILD/deps/classes"
if [ -d "$DEPS_CLASSES" ]; then
    while IFS= read -r -d '' f; do
        CLASS_FILES+=("$f")
    done < <(find "$DEPS_CLASSES" -name "*.class" -print0)
fi

[ "${#CLASS_FILES[@]}" -eq 0 ] && die "No compiled .class files found"

# Without --min-api, d8 desugars against its own default target rather
# than the project's declared min_sdk, which can silently produce
# bytecode that behaves differently (or breaks) on the actual minimum
# API the app claims to support.
d8 \
    --lib "$ANDROID_JAR" \
    --min-api "$MIN_SDK" \
    --output "$DEX" \
    "${CLASS_FILES[@]}"

echo
log_ok "DEX OK"
