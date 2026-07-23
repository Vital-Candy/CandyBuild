#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$ROOT/lib/common.sh"
# shellcheck source=/dev/null
source "$ROOT/lib/ndk.sh"

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}        CandyBuild Installer${NC}"
echo -e "${BLUE}=========================================${NC}"
echo

if [ ! -d "/data/data/com.termux" ]; then
    log_warn "This installer targets Termux. Continuing, but paths may differ on other systems."
fi

# Shared storage (/sdcard, /storage/emulated/...) is FAT/FUSE-backed and
# does not support the Unix executable bit — `chmod +x` there either
# fails or silently doesn't stick. A CandyBuild install placed there
# would fail with a confusing "Permission denied" on every command, not
# because of a bug in the scripts but because the OS itself won't
# execute files from that filesystem. Rather than just warning about it,
# copy CandyBuild into Termux's own home directory automatically and
# continue the install from there.
TARGET_HOME="$HOME/.candybuild"
case "$ROOT" in
    /sdcard*|/storage*)
        if [ "$ROOT" != "$TARGET_HOME" ]; then
            log_warn "$ROOT is on shared storage, which can't run executables."
            log_info "Copying CandyBuild to $TARGET_HOME instead..."
            rm -rf "$TARGET_HOME"
            cp -r "$ROOT" "$TARGET_HOME"
            chmod +x "$TARGET_HOME/bin/candybuild"
            chmod +x "$TARGET_HOME"/commands/*.sh
            chmod +x "$TARGET_HOME"/compiler/*.sh
            chmod +x "$TARGET_HOME/install.sh"
            log_ok "Copied — continuing installation from $TARGET_HOME"
            echo
            # Re-exec from the new location so every path below (ROOT,
            # the doctor run at the end, the symlink target, etc.) is
            # correct for where CandyBuild actually ends up living. The
            # original copy on shared storage is left untouched — only
            # your projects need to live there, not the tool itself.
            exec bash "$TARGET_HOME/install.sh" "$@"
        fi
        ;;
esac

log_info "[1/8] Updating packages"
pkg update -y && pkg upgrade -y

log_info "[2/8] Installing Java (OpenJDK 21)"
pkg install openjdk-21 -y

log_info "[3/8] Installing Kotlin"
pkg install kotlin -y

log_info "[4/8] Installing Android build tools"
pkg install aapt2 d8 apksigner zip unzip curl -y
if command -v zipalign >/dev/null 2>&1; then
    log_ok "zipalign already available"
else
    pkg install zipalign -y || log_warn "zipalign not found under that package name — see docs/SDK.md"
fi

log_info "[5/8] Installing C++ toolchain (for native/game code)"
pkg install clang -y
pkg install ndk-sysroot -y || true
if ndk_sysroot_installed; then
    log_ok "Native (C++) toolchain ready"
else
    log_warn "ndk-sysroot did not install correctly — C++ projects won't build until this is fixed. See docs/NATIVE.md"
fi

# ---------------------------------------------------------------------------
# [6/8] Android SDK platform (android.jar) — previously the one manual step
# left after installing CandyBuild. This downloads Google's official
# command-line-tools package and uses it to fetch just the platform jar,
# without ever touching Gradle or Android Studio.
# ---------------------------------------------------------------------------
log_info "[6/8] Installing Android SDK platform (android.jar)"

SDK_ROOT="$HOME/.candybuild/sdk"
CMDLINE_TOOLS="$SDK_ROOT/cmdline-tools/latest"
TARGET_API="$(grep -E '^TARGET_SDK=' "$ROOT/config/default.conf" | cut -d= -f2)"
TARGET_API="${TARGET_API:-34}"

if [ -x "$CMDLINE_TOOLS/bin/sdkmanager" ]; then
    log_ok "Android command-line tools already installed"
else
    # The build number in this URL changes over time (Google ships new
    # command-line-tools releases periodically) — scrape the current one
    # from the official download page instead of trusting a hardcoded
    # number that will eventually go stale. Falls back to a known-good
    # build if the page layout ever changes underneath us.
    log_info "Looking up the current command-line-tools build..."
    STUDIO_PAGE="$(curl -fsSL https://developer.android.com/studio 2>/dev/null || true)"
    ZIP_NAME="$(echo "$STUDIO_PAGE" | grep -oE 'commandlinetools-linux-[0-9]+_latest\.zip' | head -n1)"
    if [ -z "$ZIP_NAME" ]; then
        ZIP_NAME="commandlinetools-linux-14742923_latest.zip"
        log_warn "Could not detect the current build from the download page — falling back to a known build ($ZIP_NAME). If this fails, check docs/SDK.md for a manual link."
    fi

    log_info "Downloading $ZIP_NAME (~170MB, this can take a while on mobile data)..."
    TMP_ZIP="$(mktemp)"
    if curl -fsSL "https://dl.google.com/android/repository/$ZIP_NAME" -o "$TMP_ZIP"; then
        mkdir -p "$SDK_ROOT/cmdline-tools"
        unzip -qq -o "$TMP_ZIP" -d "$SDK_ROOT/cmdline-tools"
        # The zip extracts to cmdline-tools/cmdline-tools/ — sdkmanager
        # specifically requires a "latest" (or version-named) subfolder,
        # or it refuses to run.
        rm -rf "$CMDLINE_TOOLS"
        mv "$SDK_ROOT/cmdline-tools/cmdline-tools" "$CMDLINE_TOOLS"
        rm -f "$TMP_ZIP"
    else
        rm -f "$TMP_ZIP"
        log_warn "Download failed (no network?) — see docs/SDK.md to set this up manually later."
    fi
fi

if [ -x "$CMDLINE_TOOLS/bin/sdkmanager" ]; then
    # Plain /tmp/whatever is not necessarily writable in Termux (its real
    # tmp dir is $PREFIX/tmp, exposed as $TMPDIR) — mktemp respects
    # $TMPDIR automatically, a hardcoded /tmp path can silently fail here.
    SDKMANAGER_LOG="$(mktemp)"

    log_info "Accepting Android SDK licenses..."
    yes | "$CMDLINE_TOOLS/bin/sdkmanager" --sdk_root="$SDK_ROOT" --licenses >"$SDKMANAGER_LOG" 2>&1 || true

    log_info "Installing platform android-$TARGET_API..."
    if "$CMDLINE_TOOLS/bin/sdkmanager" --sdk_root="$SDK_ROOT" "platforms;android-$TARGET_API" >>"$SDKMANAGER_LOG" 2>&1; then
        log_ok "android-$TARGET_API installed"
    else
        log_warn "sdkmanager failed to install the platform — see $SDKMANAGER_LOG"
    fi

    if ! grep -q "ANDROID_HOME=\"$SDK_ROOT\"" "$HOME/.bashrc" 2>/dev/null; then
        echo "export ANDROID_HOME=\"$SDK_ROOT\"" >> "$HOME/.bashrc"
    fi
    export ANDROID_HOME="$SDK_ROOT"
fi

log_info "[7/8] Preparing CandyBuild home"
mkdir -p "$HOME/.candybuild"

log_info "[8/8] Linking the candybuild command"
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
echo "  source ~/.bashrc   (or restart Termux, to pick up ANDROID_HOME)"
echo "  candybuild doctor"
echo "  candybuild new MyApp"
echo
