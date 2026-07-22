#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$BASE/lib/common.sh"
# shellcheck source=/dev/null
source "$BASE/lib/toml.sh"
# shellcheck source=/dev/null
source "$BASE/lib/maven.sh"

PROJECT="${1:-}"
[ -z "$PROJECT" ] && die "project path missing"

BUILD="$PROJECT/build"
DEPS="$BUILD/deps"
DEPS_CLASSES="$DEPS/classes"   # unpacked .class files from every dependency, merged
DEPS_JARS="$DEPS/jars"         # classes.jar / plain .jar per artifact, for -classpath
DEPS_RES="$DEPS/res"           # one subfolder per artifact with its res/, for aapt2 --dir

rm -rf "$DEPS"
mkdir -p "$DEPS_CLASSES" "$DEPS_JARS" "$DEPS_RES"

# Nothing declared? Fine — most projects have no dependencies. Leave the
# (empty) build/deps/ folders so later steps don't need special-casing.
DIRECT_DEPS=()
while IFS= read -r d; do
    [ -n "$d" ] && DIRECT_DEPS+=("$d")
done < <(toml_get_all "$PROJECT/Candy.toml" dependency)

if [ "${#DIRECT_DEPS[@]}" -eq 0 ]; then
    log_info "No dependencies declared"
    exit 0
fi

require_cmd curl
require_cmd unzip

log_info "Resolving ${#DIRECT_DEPS[@]} declared dependency(ies) via Maven Central..."

RESOLVED=()
while IFS= read -r c; do
    [ -n "$c" ] && RESOLVED+=("$c")
done < <(maven_resolve "${DIRECT_DEPS[@]}")

log_info "Resolved ${#RESOLVED[@]} artifact(s) total (including transitive)"

for coord in "${RESOLVED[@]}"; do
    g="${coord%%:*}"; rest="${coord#*:}"
    a="${rest%%:*}"; v="${rest#*:}"

    artifact_file="$(maven_artifact_file "$g" "$a" "$v")" || {
        log_warn "Skipping $coord — could not download .aar or .jar"
        continue
    }

    workdir="$DEPS/_unpack/$a-$v"
    rm -rf "$workdir"
    mkdir -p "$workdir"

    case "$artifact_file" in
        *.aar)
            unzip -qq -o "$artifact_file" -d "$workdir"
            if [ -f "$workdir/classes.jar" ]; then
                cp "$workdir/classes.jar" "$DEPS_JARS/$a-$v.jar"
            fi
            if [ -d "$workdir/res" ] && [ -n "$(find "$workdir/res" -mindepth 1 -print -quit 2>/dev/null)" ]; then
                mkdir -p "$DEPS_RES/$a-$v"
                cp -r "$workdir/res" "$DEPS_RES/$a-$v/"
            fi
            # NOTE: we intentionally do not merge this AAR's AndroidManifest.xml
            # into the project's manifest (no manifest-merger equivalent here).
            # If a library needs manifest entries (permissions, providers,
            # services), add them to the project's own AndroidManifest.xml
            # by hand — see docs/DEPENDENCIES.md.
            ;;
        *.jar)
            cp "$artifact_file" "$DEPS_JARS/$a-$v.jar"
            ;;
    esac
done

# Explode every dependency jar's .class files into one shared folder so
# dex.sh can dex them alongside the project's own classes without needing
# to know about each jar individually.
for jar in "$DEPS_JARS"/*.jar; do
    [ -e "$jar" ] || continue
    unzip -qq -o "$jar" -d "$DEPS_CLASSES" -x "META-INF/*" || true
done

echo
log_ok "Dependencies ready ($(find "$DEPS_JARS" -name '*.jar' | wc -l) jar(s), $(find "$DEPS_RES" -mindepth 1 -maxdepth 1 -type d | wc -l) with resources)"
