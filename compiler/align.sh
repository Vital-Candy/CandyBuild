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
INPUT="$OUT/$APK_NAME"
ALIGNED="$OUT/.aligned-$APK_NAME"

[ -f "$INPUT" ] || die "APK not found: $INPUT"

require_cmd zipalign

zipalign -f 4 "$INPUT" "$ALIGNED"
mv "$ALIGNED" "$INPUT"

log_ok "Zipalign OK"
