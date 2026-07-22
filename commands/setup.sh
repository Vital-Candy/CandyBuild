#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/lib/common.sh"

PROJECT="${1:-}"
[ -z "$PROJECT" ] && die "Usage: candybuild setup <project_path>"

echo "========================================="
echo "      CandyBuild Project Setup"
echo "========================================="

mkdir -p "$PROJECT/res/layout"
mkdir -p "$PROJECT/res/drawable"
mkdir -p "$PROJECT/res/anim"
mkdir -p "$PROJECT/res/font"
mkdir -p "$PROJECT/res/color"
mkdir -p "$PROJECT/res/menu"
mkdir -p "$PROJECT/res/xml"
mkdir -p "$PROJECT/res/mipmap-anydpi-v26"
mkdir -p "$PROJECT/res/values"

mkdir -p "$PROJECT/src/ui"
mkdir -p "$PROJECT/src/core"
mkdir -p "$PROJECT/src/model"
mkdir -p "$PROJECT/src/adapter"
mkdir -p "$PROJECT/src/utils"

# Only create files that don't already exist — running `setup` again on an
# existing project must never wipe out work in progress.
#
# These MUST be written as valid, minimal XML. An empty (0-byte) file is
# not well-formed XML, and `aapt2 compile` fails on it — that used to
# break `candybuild build` on a project immediately after `candybuild new`,
# before the user had touched a single file.
write_if_missing() {
    local path="$1" content="$2"
    [ -f "$PROJECT/$path" ] && return 0
    printf '%s\n' "$content" > "$PROJECT/$path"
}

write_if_missing res/layout/activity_main.xml \
'<?xml version="1.0" encoding="utf-8"?>
<FrameLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent" />'

write_if_missing res/values/colors.xml \
'<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="black">#FF000000</color>
    <color name="white">#FFFFFFFF</color>
</resources>'

write_if_missing res/values/themes.xml \
'<?xml version="1.0" encoding="utf-8"?>
<resources>
</resources>'

write_if_missing res/values/styles.xml \
'<?xml version="1.0" encoding="utf-8"?>
<resources>
</resources>'

write_if_missing res/values/dimens.xml \
'<?xml version="1.0" encoding="utf-8"?>
<resources>
    <dimen name="margin_default">16dp</dimen>
</resources>'

echo
log_ok "Project structure ready"
