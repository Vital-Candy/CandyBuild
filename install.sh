#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$ROOT/lib/common.sh"

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}        CandyBuild Installer${NC}"
echo -e "${BLUE}=========================================${NC}"
echo

if [ ! -d "/data/data/com.termux" ]; then
    log_warn "This installer targets Termux. Continuing, but paths may differ on other systems."
fi

log_info "[1/7] Updating packages"
pkg update -y && pkg upgrade -y

log_info "[2/7] Installing Java (OpenJDK 21)"
pkg install openjdk-21 -y

log_info "[3/7] Installing Kotlin"
pkg install kotlin -y

log_info "[4/7] Installing Android build tools"
pkg install aapt2 d8 apksigner zip unzip curl -y
pkg install zipalign -y || log_warn "zipalign not found under that package name — see docs/SDK.md"

log_info "[5/7] Installing C++ toolchain (for native/game code)"
pkg install clang -y
pkg install ndk-sysroot -y || log_warn "ndk-sysroot not found — C++ projects won't build until you install it or set ANDROID_NDK_HOME. See docs/NATIVE.md"

log_info "[6/7] Preparing CandyBuild home"
mkdir -p "$HOME/.candybuild"

log_info "[7/7] Linking the candybuild command"
chmod +x "$ROOT/bin/candybuild"
chmod +x "$ROOT"/commands/*.sh
chmod +x "$ROOT"/compiler/*.sh
ln -sf "$ROOT/bin/candybuild" "$PREFIX/bin/candybuild"

echo
bash "$ROOT/commands/doctor.sh"

echo
echo -e "${BLUE}=========================================${NC}"
echo -e "${GREEN} CandyBuild installed${NC}"
echo -e "${BLUE}=========================================${NC}"
echo
echo "Next steps:"
echo "  candybuild doctor"
echo "  candybuild new MyApp"
echo
echo "Note: you still need an Android SDK 'platforms' folder"
echo "(android.jar) to actually compile anything. This is NOT"
echo "installed automatically — see docs/SDK.md for the options."
echo
