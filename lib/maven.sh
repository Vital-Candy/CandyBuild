#!/data/data/com.termux/files/usr/bin/bash
# Minimal Maven Central dependency resolver.
#
# This is NOT a Maven/Gradle reimplementation. It handles the common case
# (AndroidX-style artifacts with a flat <dependencies> list) well enough
# to pull in Compose. It deliberately does NOT support:
#   - parent POM inheritance (properties/deps defined in a <parent>)
#   - <dependencyManagement> / BOM imports
#   - version ranges ([1.0,2.0))
#   - property placeholders that aren't defined in the same POM's
#     <properties> block (e.g. ${kotlin.version} from a parent)
#
# If a transitive dependency can't be resolved, we log a warning and skip
# it rather than fail the whole build — the caller can pin it explicitly
# as a direct `dependency = "..."` in Candy.toml instead.
#
# Requires: curl, unzip (added to install.sh)

MAVEN_REPO="https://repo1.maven.org/maven2"
MAVEN_CACHE="$HOME/.candybuild/cache/maven"

_maven_group_path() { echo "${1//./\/}"; }

# _maven_url <group> <artifact> <version> <ext>
_maven_url() {
    local group="$1" artifact="$2" version="$3" ext="$4"
    echo "$MAVEN_REPO/$(_maven_group_path "$group")/$artifact/$version/$artifact-$version.$ext"
}

# _maven_cache_file <group> <artifact> <version> <ext>
_maven_cache_file() {
    local group="$1" artifact="$2" version="$3" ext="$4"
    echo "$MAVEN_CACHE/$(_maven_group_path "$group")/$artifact/$version/$artifact-$version.$ext"
}

# maven_fetch <group> <artifact> <version> <ext> -> prints path to cached file, or fails
maven_fetch() {
    local group="$1" artifact="$2" version="$3" ext="$4"
    local dest url
    dest="$(_maven_cache_file "$group" "$artifact" "$version" "$ext")"

    if [ -f "$dest" ]; then
        echo "$dest"
        return 0
    fi

    mkdir -p "$(dirname "$dest")"
    url="$(_maven_url "$group" "$artifact" "$version" "$ext")"

    if curl -fsSL "$url" -o "$dest.tmp" 2>/dev/null; then
        mv "$dest.tmp" "$dest"
        echo "$dest"
        return 0
    fi

    rm -f "$dest.tmp"
    return 1
}

# _maven_pom_property <pom_file> <prop_name> -> value or empty
_maven_pom_property() {
    local pom="$1" prop="$2"
    sed -n "s#.*<${prop}>\\(.*\\)</${prop}>.*#\\1#p" "$pom" | head -n1
}

# _maven_expand <pom_file> <value> -> resolves a single ${...} using that
# POM's own <properties> block, or common built-ins. Leaves it untouched
# (with a warning upstream) if it can't be resolved.
_maven_expand() {
    local pom="$1" val="$2" prop resolved
    case "$val" in
        '${'*'}')
            prop="${val#\$\{}"; prop="${prop%\}}"
            case "$prop" in
                project.version) resolved="$(_maven_pom_property "$pom" version)" ;;
                *) resolved="$(_maven_pom_property "$pom" "$prop")" ;;
            esac
            [ -n "$resolved" ] && { echo "$resolved"; return 0; }
            return 1
            ;;
        *) echo "$val"; return 0 ;;
    esac
}

# _maven_deps_from_pom <pom_file> -> lines of "group:artifact:version"
# for compile/runtime-scope, non-optional dependencies.
_maven_deps_from_pom() {
    local pom="$1"
    # Strip comments, then split into one <dependency>...</dependency> per line.
    sed 's/<!--.*-->//g' "$pom" \
        | tr -d '\n' \
        | grep -oE '<dependency>.*?</dependency>' \
        | sed 's/<dependency>/\n<dependency>/g' \
        | grep '<dependency>' \
    | while IFS= read -r block; do
        local g a v scope optional
        g="$(echo "$block" | sed -n 's#.*<groupId>\(.*\)</groupId>.*#\1#p' | head -n1)"
        a="$(echo "$block" | sed -n 's#.*<artifactId>\(.*\)</artifactId>.*#\1#p' | head -n1)"
        v="$(echo "$block" | sed -n 's#.*<version>\(.*\)</version>.*#\1#p' | head -n1)"
        scope="$(echo "$block" | sed -n 's#.*<scope>\(.*\)</scope>.*#\1#p' | head -n1)"
        optional="$(echo "$block" | sed -n 's#.*<optional>\(.*\)</optional>.*#\1#p' | head -n1)"

        [ "$optional" = "true" ] && continue
        case "$scope" in test|provided) continue ;; esac
        [ -z "$g" ] || [ -z "$a" ] && continue

        if [ -n "$v" ]; then
            v="$(_maven_expand "$pom" "$v")" || {
                log_warn "maven: could not resolve version for $g:$a (property in $v), skipping transitive dep"
                continue
            }
        fi
        [ -z "$v" ] && continue

        echo "$g:$a:$v"
    done
}

# maven_resolve <coord...> -> prints a de-duplicated, newline-separated
# list of resolved "group:artifact:version" coordinates (the requested
# ones plus everything transitively required), via breadth-first search.
# On version conflicts for the same group:artifact, first-seen wins —
# same simplification real build tools call "nearest wins", just without
# actually measuring distance. Put the version you want directly in
# Candy.toml if this picks the wrong one.
maven_resolve() {
    local -A seen=()
    local queue=("$@")
    local resolved=()

    while [ "${#queue[@]}" -gt 0 ]; do
        local coord="${queue[0]}"
        queue=("${queue[@]:1}")

        local g a v
        IFS=':' read -r g a v <<< "$coord"
        local key="$g:$a"

        [ -n "${seen[$key]:-}" ] && continue
        seen[$key]="$v"
        resolved+=("$g:$a:$v")

        local pom
        if pom="$(maven_fetch "$g" "$a" "$v" pom)"; then
            while IFS= read -r dep; do
                [ -z "$dep" ] && continue
                queue+=("$dep")
            done < <(_maven_deps_from_pom "$pom")
        else
            log_warn "maven: could not fetch POM for $coord (network or coordinate is wrong)"
        fi
    done

    printf '%s\n' "${resolved[@]}"
}

# maven_artifact_file <group> <artifact> <version> -> path to .aar or .jar
# (tries .aar first — that's how almost everything AndroidX is packaged).
maven_artifact_file() {
    local g="$1" a="$2" v="$3" f
    if f="$(maven_fetch "$g" "$a" "$v" aar)"; then
        echo "$f"; return 0
    fi
    if f="$(maven_fetch "$g" "$a" "$v" jar)"; then
        echo "$f"; return 0
    fi
    return 1
}
