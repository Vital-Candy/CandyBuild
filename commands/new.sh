#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/lib/common.sh"
# shellcheck source=/dev/null
source "$ROOT/lib/toml.sh"

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}          CandyBuild v0.3${NC}"
echo -e "${BLUE}=========================================${NC}"
echo

# README says `candybuild new MyApp` — honor that instead of only
# accepting the name interactively (the original bug).
PROJECT="${1:-}"
if [ -z "$PROJECT" ]; then
    read -rp "Project name: " PROJECT || true
fi
[ -z "$PROJECT" ] && die "Project name is required."

read -rp "App name [$PROJECT]: " APP_NAME || true
APP_NAME="${APP_NAME:-$PROJECT}"

DEFAULT_PACKAGE="com.example.${PROJECT,,}"
read -rp "Package name [$DEFAULT_PACKAGE]: " PACKAGE || true
PACKAGE="${PACKAGE:-$DEFAULT_PACKAGE}"

DEFAULT_DIR="$PWD"
read -rp "Project location [$DEFAULT_DIR]: " PROJECT_PATH || true
PROJECT_PATH="${PROJECT_PATH:-$DEFAULT_DIR}"

DEFAULT_MINSDK="$(toml_get "$ROOT/config/default.conf" MIN_SDK 26)"
read -rp "Min SDK [$DEFAULT_MINSDK]: " MINSDK || true
MINSDK="${MINSDK:-$DEFAULT_MINSDK}"

DEFAULT_TARGETSDK="$(toml_get "$ROOT/config/default.conf" TARGET_SDK 34)"
read -rp "Target SDK [$DEFAULT_TARGETSDK]: " TARGETSDK || true
TARGETSDK="${TARGETSDK:-$DEFAULT_TARGETSDK}"

read -rp "Version code [1]: " VERSIONCODE || true
VERSIONCODE="${VERSIONCODE:-1}"

read -rp "Version name [1.0]: " VERSIONNAME || true
VERSIONNAME="${VERSIONNAME:-1.0}"

echo
read -rp "Language — kotlin/java [kotlin]: " LANGUAGE || true
LANGUAGE="${LANGUAGE:-kotlin}"
case "$LANGUAGE" in
    kotlin|java) ;;
    *) die "Language must be 'kotlin' or 'java'" ;;
esac

UI="views"
if [ "$LANGUAGE" = "kotlin" ]; then
    read -rp "UI — views/compose [views]: " UI || true
    UI="${UI:-views}"
    case "$UI" in
        views|compose) ;;
        *) die "UI must be 'views' or 'compose'" ;;
    esac
else
    log_warn "Jetpack Compose is Kotlin-only — using classic Views for a Java project."
fi

read -rp "Add native C++ code, e.g. for a game engine? y/N: " NATIVE_CHOICE || true
case "${NATIVE_CHOICE,,}" in
    y|yes) NATIVE=1 ;;
    *)     NATIVE=0 ;;
esac
NATIVE_LIB_NAME="native"

DEST="$PROJECT_PATH/$PROJECT"
[ -e "$DEST" ] && die "Destination already exists: $DEST"

echo
log_info "Creating project..."

mkdir -p "$DEST/src"
mkdir -p "$DEST/res/values"
mkdir -p "$DEST/assets"
mkdir -p "$DEST/libs"
mkdir -p "$DEST/out"
[ "$NATIVE" -eq 1 ] && mkdir -p "$DEST/cpp"

# Compose pulls in AndroidX artifacts via lib/maven.sh (real Maven Central
# resolution — network required at build time, not at `new` time). These
# are a known-good starting point for Kotlin 2.0+'s bundled K2 compose
# compiler; if `candybuild build` reports a version mismatch, adjust
# these `dependency` lines by hand — see docs/DEPENDENCIES.md.
COMPOSE_DEPS=""
if [ "$UI" = "compose" ]; then
    COMPOSE_DEPS='dependency="androidx.activity:activity-compose:1.9.0"
dependency="androidx.compose.ui:ui:1.6.7"
dependency="androidx.compose.ui:ui-tooling-preview:1.6.7"
dependency="androidx.compose.foundation:foundation:1.6.7"
dependency="androidx.compose.material:material:1.6.7"
dependency="androidx.compose.runtime:runtime:1.6.7"'
fi

cat > "$DEST/Candy.toml" <<EOF
package="$PACKAGE"

app_name="$APP_NAME"

min_sdk=$MINSDK
target_sdk=$TARGETSDK

version_code=$VERSIONCODE
version_name="$VERSIONNAME"

language="$LANGUAGE"
ui="$UI"
$([ "$NATIVE" -eq 1 ] && echo "native_lib_name=\"$NATIVE_LIB_NAME\"")

$COMPOSE_DEPS
EOF

PACKAGE_PATH="${PACKAGE//./\/}"
mkdir -p "$DEST/src/$PACKAGE_PATH"

MANIFEST_THEME="@android:style/Theme.Black.NoTitleBar"
[ "$UI" = "compose" ] && MANIFEST_THEME="@android:style/Theme.Material.Light.NoActionBar"

cat > "$DEST/AndroidManifest.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="$PACKAGE">

    <application
        android:label="$APP_NAME"
        android:theme="$MANIFEST_THEME">

        <activity
            android:name=".MainActivity"
            android:exported="true">

            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>

        </activity>

    </application>

</manifest>
EOF

if [ "$NATIVE" -eq 1 ]; then
    PACKAGE_JNI="${PACKAGE//./_}"
    cat > "$DEST/cpp/native-lib.cpp" <<EOF
#include <jni.h>
#include <string>

// JNI naming convention: Java_<package_with_dots_as_underscores>_<Class>_<method>.
// If your package or class name ever contains an underscore, escape it
// as "_1" in the function name (see the JNI spec) — this template
// assumes a plain, underscore-free package name.
extern "C" JNIEXPORT jstring JNICALL
Java_${PACKAGE_JNI}_MainActivity_stringFromJNI(JNIEnv* env, jobject /* this */) {
    std::string hello = "Hello from C++";
    return env->NewStringUTF(hello.c_str());
}
EOF
fi

if [ "$LANGUAGE" = "java" ]; then
    if [ "$NATIVE" -eq 1 ]; then
        cat > "$DEST/src/$PACKAGE_PATH/MainActivity.java" <<EOF
package $PACKAGE;

import android.app.Activity;
import android.graphics.Color;
import android.os.Bundle;
import android.view.Gravity;
import android.widget.TextView;

public class MainActivity extends Activity {

    static {
        System.loadLibrary("$NATIVE_LIB_NAME");
    }

    public native String stringFromJNI();

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        TextView tv = new TextView(this);
        tv.setText("HELLO WORLD\nby candy\n" + stringFromJNI());
        tv.setGravity(Gravity.CENTER);
        tv.setTextSize(24f);
        tv.setTextColor(Color.WHITE);
        tv.setBackgroundColor(Color.BLACK);

        setContentView(tv);
    }
}
EOF
    else
        cat > "$DEST/src/$PACKAGE_PATH/MainActivity.java" <<EOF
package $PACKAGE;

import android.app.Activity;
import android.graphics.Color;
import android.os.Bundle;
import android.view.Gravity;
import android.widget.TextView;

public class MainActivity extends Activity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        TextView tv = new TextView(this);
        tv.setText("HELLO WORLD\nby candy");
        tv.setGravity(Gravity.CENTER);
        tv.setTextSize(24f);
        tv.setTextColor(Color.WHITE);
        tv.setBackgroundColor(Color.BLACK);

        setContentView(tv);
    }
}
EOF
    fi
elif [ "$UI" = "compose" ]; then
    if [ "$NATIVE" -eq 1 ]; then
        cat > "$DEST/src/$PACKAGE_PATH/MainActivity.kt" <<EOF
package $PACKAGE

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material.MaterialTheme
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier

class MainActivity : ComponentActivity() {

    companion object {
        init { System.loadLibrary("$NATIVE_LIB_NAME") }
    }

    external fun stringFromJNI(): String

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val nativeGreeting = stringFromJNI()
        setContent {
            MaterialTheme {
                Greeting(nativeGreeting)
            }
        }
    }
}

@Composable
fun Greeting(nativeGreeting: String) {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Text("HELLO WORLD\nby candy\n\$nativeGreeting")
    }
}
EOF
    else
        cat > "$DEST/src/$PACKAGE_PATH/MainActivity.kt" <<EOF
package $PACKAGE

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material.MaterialTheme
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier

class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                Greeting()
            }
        }
    }
}

@Composable
fun Greeting() {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Text("HELLO WORLD\nby candy")
    }
}
EOF
    fi
else
    if [ "$NATIVE" -eq 1 ]; then
        cat > "$DEST/src/$PACKAGE_PATH/MainActivity.kt" <<EOF
package $PACKAGE

import android.app.Activity
import android.graphics.Color
import android.os.Bundle
import android.view.Gravity
import android.widget.TextView

class MainActivity : Activity() {

    companion object {
        init { System.loadLibrary("$NATIVE_LIB_NAME") }
    }

    external fun stringFromJNI(): String

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val tv = TextView(this)

        tv.text = "HELLO WORLD\nby candy\n" + stringFromJNI()
        tv.gravity = Gravity.CENTER
        tv.textSize = 24f
        tv.setTextColor(Color.WHITE)
        tv.setBackgroundColor(Color.BLACK)

        setContentView(tv)
    }
}
EOF
    else
        cat > "$DEST/src/$PACKAGE_PATH/MainActivity.kt" <<EOF
package $PACKAGE

import android.app.Activity
import android.graphics.Color
import android.os.Bundle
import android.view.Gravity
import android.widget.TextView

class MainActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val tv = TextView(this)

        tv.text = "HELLO WORLD\nby candy"
        tv.gravity = Gravity.CENTER
        tv.textSize = 24f
        tv.setTextColor(Color.WHITE)
        tv.setBackgroundColor(Color.BLACK)

        setContentView(tv)
    }
}
EOF
    fi
fi

cat > "$DEST/res/values/strings.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">$APP_NAME</string>
</resources>
EOF

cat > "$DEST/.gitignore" <<EOF
build/
out/
EOF

# Fill in the rest of the folder layout (res/layout, src/ui, etc.)
# so users never have to remember to call `setup` separately.
bash "$ROOT/commands/setup.sh" "$DEST" >/dev/null

echo
log_ok "Project created"
echo
echo "Name:     $PROJECT"
echo "Path:     $DEST"
echo "Package:  $PACKAGE"
echo "Language: $LANGUAGE"
echo "UI:       $UI"
[ "$NATIVE" -eq 1 ] && echo "Native:   yes (cpp/native-lib.cpp)"
echo
echo "Next step:"
echo "  candybuild build \"$DEST\""
echo
