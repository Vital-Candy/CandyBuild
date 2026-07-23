#!/data/data/com.termux/files/usr/bin/bash
# Locates a way to compile C++ that actually targets Android (Bionic)
# correctly, with the Android NDK's headers/libs available — not just
# whatever plain `clang` happens to default to.
#
# Two options, in order of preference:
#   a) a full Android NDK (ANDROID_NDK_HOME) with its own clang wrapper
#   b) Termux's own `clang` + the `ndk-sysroot` package (installed by
#      install.sh via `pkg install clang ndk-sysroot`)
#
# IMPORTANT, and the reason this file looks the way it does: the real
# `ndk-sysroot` Termux package does NOT create a `$PREFIX/opt/ndk-sysroot`
# folder — it merges the NDK's headers straight into `$PREFIX/include`
# and its libs into `$PREFIX/lib` (see termux/termux-packages
# packages/ndk-sysroot/build.sh). An earlier version of this file checked
# for that folder, which never exists, so it always reported "missing"
# even right after a successful `pkg install ndk-sysroot`. We now check
# for a real file the package installs instead, and don't pass a
# `--sysroot=` flag at all — once merged into $PREFIX, clang already
# finds those headers on its normal default search path.

android_abi() {
    case "$(uname -m)" in
        aarch64) echo "arm64-v8a" ;;
        armv7l|armv8l) echo "armeabi-v7a" ;;
        x86_64) echo "x86_64" ;;
        i686|i386) echo "x86" ;;
        *) return 1 ;;
    esac
}

# _android_triple <abi> <api> -> clang target triple
_android_triple() {
    local abi="$1" api="$2"
    case "$abi" in
        arm64-v8a)    echo "aarch64-linux-android$api" ;;
        armeabi-v7a)  echo "armv7a-linux-androideabi$api" ;;
        x86_64)       echo "x86_64-linux-android$api" ;;
        x86)          echo "i686-linux-android$api" ;;
        *) return 1 ;;
    esac
}

# ndk_sysroot_installed -> true if the Termux `ndk-sysroot` package looks
# installed. android/log.h is a solid marker: it ships with the NDK
# headers (needed for __android_log_print / the -llog flag native.sh
# already uses) and isn't part of a bare Termux install without it.
ndk_sysroot_installed() {
    [ -f "${PREFIX:-/data/data/com.termux/files/usr}/include/android/log.h" ]
}

# resolve_cxx_compiler <api> -> prints "COMPILER_CMD|EXTRA_FLAGS", or fails
# with a clear reason on stderr. EXTRA_FLAGS may be empty.
resolve_cxx_compiler() {
    local api="$1" abi triple

    abi="$(android_abi)" || { echo "Unrecognized host architecture: $(uname -m)" >&2; return 1; }
    triple="$(_android_triple "$abi" "$api")" || return 1

    # Option A: full Android NDK
    if [ -n "${ANDROID_NDK_HOME:-}" ]; then
        local ndk_clang
        ndk_clang="$(find "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt" -maxdepth 2 -name "${triple}-clang++" 2>/dev/null | head -n1)"
        if [ -n "$ndk_clang" ] && [ -x "$ndk_clang" ]; then
            echo "$ndk_clang|"
            return 0
        fi
        echo "ANDROID_NDK_HOME is set but no ${triple}-clang++ found under it" >&2
    fi

    # Option B: Termux's clang + the `ndk-sysroot` package. No --sysroot
    # flag needed — ndk-sysroot's headers/libs are merged into $PREFIX
    # itself, already on clang's default search path. -target still
    # pins the exact API level from Candy.toml's min_sdk rather than
    # whatever Termux's clang defaults to.
    if command -v clang++ >/dev/null 2>&1; then
        if ndk_sysroot_installed; then
            echo "clang++|-target $triple"
            return 0
        fi
        echo "clang++ found, but the ndk-sysroot package is missing (run: pkg install ndk-sysroot)" >&2
    else
        echo "clang++ not found (run: pkg install clang)" >&2
    fi

    return 1
}
