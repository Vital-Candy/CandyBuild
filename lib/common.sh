#!/data/data/com.termux/files/usr/bin/bash
# Shared helpers. Sourced by every script — never executed directly.

GREEN="\033[0;32m"
RED="\033[0;31m"
BLUE="\033[0;34m"
YELLOW="\033[1;33m"
NC="\033[0m"

log_info() { echo -e "${BLUE}==>${NC} $*"; }
log_ok()   { echo -e "${GREEN}✔${NC} $*"; }
log_warn() { echo -e "${YELLOW}!${NC} $*"; }
log_err()  { echo -e "${RED}✘${NC} $*" >&2; }

die() {
    log_err "$*"
    exit 1
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "Required tool not found: $1 (run 'candybuild doctor')"
}
