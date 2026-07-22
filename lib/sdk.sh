#!/data/data/com.termux/files/usr/bin/bash
# Resolves the android.jar to build against.
#
# This is the ONLY place that looks for android.jar. Every compiler/*.sh
# step calls resolve_android_jar instead of re-implementing its own search.
# (In the original version, resources.sh and kotlin.sh searched
# dynamically while dex.sh hardcoded "android-36" — they could silently
# use two different jars in the same build. That inconsistency is gone.)
#
# Usage: jar="$(resolve_android_jar <target_sdk>)" || die "..."

resolve_android_jar() {
    local target="$1"
    local jar

    if [ -n "${ANDROID_HOME:-}" ] && [ -d "$ANDROID_HOME/platforms" ]; then
        # Prefer an exact match for the project's target_sdk.
        if [ -f "$ANDROID_HOME/platforms/android-$target/android.jar" ]; then
            echo "$ANDROID_HOME/platforms/android-$target/android.jar"
            return 0
        fi
        # Otherwise fall back to the newest platform available.
        jar="$(find "$ANDROID_HOME/platforms" -maxdepth 2 -name android.jar 2>/dev/null | sort -V | tail -n1)"
        if [ -n "$jar" ]; then
            echo "$jar"
            return 0
        fi
    fi

    # Secondary location some users may drop platform jars into manually,
    # without needing a full SDK install. See docs/SDK.md.
    if [ -n "${CANDY_HOME:-}" ] && [ -d "$CANDY_HOME/sdk/platforms" ]; then
        jar="$(find "$CANDY_HOME/sdk/platforms" -maxdepth 2 -name android.jar 2>/dev/null | sort -V | tail -n1)"
        if [ -n "$jar" ]; then
            echo "$jar"
            return 0
        fi
    fi

    return 1
}
