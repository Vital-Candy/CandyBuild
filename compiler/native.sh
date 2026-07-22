#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$BASE/lib/common.sh"
# shellcheck source=/dev/null
source "$BASE/lib/toml.sh"
# shellcheck source=/dev/null
source "$BASE/lib/ndk.sh"

PROJECT="${1:-}"
[ -z "$PROJECT" ] && die "project path missing"

CPP_DIR="$PROJECT/cpp"
BUILD="$PROJECT/build"
NATIVE_OUT="$BUILD/native_libs"

# No cpp/ folder → nothing to do. This step is a silent no-op for the
# large majority of projects that don't use native code, same as the
# res/ check in resources.sh.
if [ ! -d "$CPP_DIR" ] || [ -z "$(find "$CPP_DIR" -name "*.cpp" -print -quit 2>/dev/null)" ]; then
    exit 0
fi

MIN_SDK="$(toml_get "$PROJECT/Candy.toml" min_sdk 26)"
LIB_NAME="$(toml_get "$PROJECT/Candy.toml" native_lib_name native)"

ABI="$(android_abi)" || die "Unrecognized host architecture ($(uname -m)) — can't determine target ABI"

ERR_LOG="$(mktemp)"
if ! RESOLVED="$(resolve_cxx_compiler "$MIN_SDK" 2>"$ERR_LOG")"; then
    die "No usable C++ cross-compiler for Android: $(cat "$ERR_LOG"). See docs/NATIVE.md."
fi
rm -f "$ERR_LOG"

CXX="${RESOLVED%%|*}"
CXX_FLAGS="${RESOLVED#*|}"

log_info "Building native code for $ABI (min-api $MIN_SDK) with $CXX"

OUT_DIR="$NATIVE_OUT/$ABI"
mkdir -p "$OUT_DIR"

CPP_FILES=()
while IFS= read -r -d '' f; do
    CPP_FILES+=("$f")
done < <(find "$CPP_DIR" -name "*.cpp" -print0)

# shellcheck disable=SC2086
"$CXX" \
    $CXX_FLAGS \
    -shared \
    -fPIC \
    -O2 \
    -Wall \
    -llog \
    -I"$CPP_DIR" \
    -o "$OUT_DIR/lib${LIB_NAME}.so" \
    "${CPP_FILES[@]}"

echo
log_ok "Native OK: $OUT_DIR/lib${LIB_NAME}.so"
