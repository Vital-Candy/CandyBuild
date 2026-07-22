#!/data/data/com.termux/files/usr/bin/bash
# Locates a way to compile C++ that actually targets Android (Bionic),
# not Termux's own userland. This distinction matters: Termux's `clang`
# by default links against Termux's own libc in $PREFIX/lib, and a .so
# built that way will NOT load inside a normal Android app process
# (System.loadLibrary will fail with a linker error) — it only runs
# inside Termux itself. A real Android .so needs either:
#   a) the Termux `ndk-sysroot` package, used with clang's -target flag, or
#   b) a full Android NDK (ANDROID_NDK_HOME) with its own clang wrapper
# We look for whichever is available and prefer (b) if both are set,
# since a full NDK is more likely to match app-facing API levels exactly.

# _android_abi -> arm64-v8a / armeabi-v7a / x86_64 / x86, based on the
# architecture Termux itself is running on (we build for the device
# we're building ON — see docs/NATIVE.md for why cross-ABI builds
# aren't supported here).
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

    # Option B: Termux's clang + the `ndk-sysroot` package
    if command -v clang++ >/dev/null 2>&1; then
        local sysroot="$PREFIX/opt/ndk-sysroot"
        if [ -d "$sysroot" ]; then
            echo "clang++|--target=$triple --sysroot=$sysroot"
            return 0
        fi
        echo "clang++ found, but $sysroot is missing (run: pkg install ndk-sysroot)" >&2
    else
        echo "clang++ not found (run: pkg install clang)" >&2
    fi

    return 1
}
