#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/lib/common.sh"

PROJECT="${1:-.}"
PROJECT="$(realpath "$PROJECT")"

[ -d "$PROJECT" ] || die "Not a directory: $PROJECT"

rm -rf "$PROJECT/build"
rm -rf "$PROJECT/out"
mkdir -p "$PROJECT/out"

log_ok "Cleaned: $PROJECT"
