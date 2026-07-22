#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$BASE/lib/common.sh"

PROJECT=""
RELEASE=0
NO_CLEAN=0

for arg in "$@"; do
    case "$arg" in
        --release)  RELEASE=1 ;;
        --no-clean) NO_CLEAN=1 ;;
        *)          PROJECT="$arg" ;;
    esac
done

[ -z "$PROJECT" ] && PROJECT="."
PROJECT="$(realpath "$PROJECT")"

[ -f "$PROJECT/Candy.toml" ] || die "Candy.toml not found in $PROJECT (is this a CandyBuild project?)"

# Stale .class/.dex files from a previous build used to be able to leak
# into a new APK. Clean by default; --no-clean opts out for faster
# incremental iteration once the project is stable.
if [ "$NO_CLEAN" -eq 0 ]; then
    rm -rf "$PROJECT/build"
fi
mkdir -p "$PROJECT/out"

export CANDY_BUILD_TYPE
if [ "$RELEASE" -eq 1 ]; then
    CANDY_BUILD_TYPE="release"
else
    CANDY_BUILD_TYPE="debug"
fi

echo
echo "========================================="
echo "     CandyBuild Build ($CANDY_BUILD_TYPE)"
echo "========================================="
echo

log_info "[1/8] Dependencies"
bash "$BASE/compiler/deps.sh" "$PROJECT"

log_info "[2/8] Resources"
bash "$BASE/compiler/resources.sh" "$PROJECT"

log_info "[3/8] Kotlin"
bash "$BASE/compiler/kotlin.sh" "$PROJECT"

log_info "[4/8] Native (C++)"
bash "$BASE/compiler/native.sh" "$PROJECT"

log_info "[5/8] DEX"
bash "$BASE/compiler/dex.sh" "$PROJECT"

log_info "[6/8] Package"
bash "$BASE/compiler/package.sh" "$PROJECT"

log_info "[7/8] Zipalign"
bash "$BASE/compiler/align.sh" "$PROJECT"

log_info "[8/8] Sign"
bash "$BASE/compiler/sign.sh" "$PROJECT"

APK_NAME="app-$CANDY_BUILD_TYPE.apk"

echo
log_ok "Build finished"
echo
echo "APK:"
echo "$PROJECT/out/$APK_NAME"
echo
