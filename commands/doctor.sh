#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/lib/common.sh"
# shellcheck source=/dev/null
source "$ROOT/lib/sdk.sh"

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}          CandyBuild Doctor${NC}"
echo -e "${BLUE}=========================================${NC}"
echo

check() {
    if command -v "$1" >/dev/null 2>&1; then
        printf "${GREEN}✔${NC} %-12s found\n" "$1"
    else
        printf "${RED}✘${NC} %-12s missing\n" "$1"
    fi
}

echo -e "${YELLOW}Tools${NC}"
echo
check java
check javac
check kotlinc
check aapt2
check d8
check apksigner
check zip
check unzip
check curl
check clang++
check candybuild

if [ -d "${PREFIX:-/nonexistent}/opt/ndk-sysroot" ] || [ -n "${ANDROID_NDK_HOME:-}" ]; then
    log_ok "Native (C++) toolchain ready"
else
    log_warn "No ndk-sysroot and no ANDROID_NDK_HOME — C++ projects won't build. See docs/NATIVE.md"
fi

if command -v zipalign >/dev/null 2>&1; then
    printf "${GREEN}✔${NC} %-12s found\n" "zipalign"
else
    printf "${YELLOW}!${NC} %-12s not found — required to align APKs, see docs/SDK.md\n" "zipalign"
fi

echo
echo -e "${YELLOW}Android SDK${NC}"
echo

if [ -n "${ANDROID_HOME:-}" ]; then
    log_ok "ANDROID_HOME=$ANDROID_HOME"
else
    log_warn "ANDROID_HOME is not set"
fi

# This is the check that was missing entirely before: the tools could all
# be "found" while builds still failed because no android.jar existed
# anywhere. Probe with a recent API level as a sane default.
if jar="$(resolve_android_jar 34)"; then
    log_ok "android.jar resolved: $jar"
else
    log_warn "No android.jar found — builds will fail until you set one up."
    echo "    See docs/SDK.md for how to get one."
fi

echo
echo -e "${YELLOW}Versions${NC}"
echo

echo -n "Java:   "
if command -v java >/dev/null 2>&1; then
    java -version 2>&1 | head -n1
else
    echo "not installed"
fi

echo -n "Kotlin: "
if command -v kotlinc >/dev/null 2>&1; then
    kotlinc -version 2>&1 | head -n1
else
    echo "not installed"
fi

echo
echo -e "${BLUE}=========================================${NC}"
echo -e "${GREEN}Check complete${NC}"
echo -e "${BLUE}=========================================${NC}"
