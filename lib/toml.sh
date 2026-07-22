#!/data/data/com.termux/files/usr/bin/bash
# Minimal reader for the flat "key = value" files CandyBuild uses
# (Candy.toml and config/default.conf). Not a full TOML parser —
# on purpose, to stay dependency-free.
#
# Usage: toml_get <file> <key> [default]

toml_get() {
    local file="$1" key="$2" default="${3:-}"
    local line val

    [ -f "$file" ] || { echo "$default"; return 0; }

    line="$(grep -E "^[[:space:]]*${key}[[:space:]]*=" "$file" | tail -n1)"
    [ -z "$line" ] && { echo "$default"; return 0; }

    val="${line#*=}"
    val="$(echo "$val" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    val="${val%\"}"
    val="${val#\"}"

    echo "$val"
}

# toml_get_all <file> <key>
# Returns every value for a repeated key, one per line — used for
# `dependency = "..."` lists, since our flat format has no real arrays.
toml_get_all() {
    local file="$1" key="$2"
    local line val

    [ -f "$file" ] || return 0

    grep -E "^[[:space:]]*${key}[[:space:]]*=" "$file" | while IFS= read -r line; do
        val="${line#*=}"
        val="$(echo "$val" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        val="${val%\"}"
        val="${val#\"}"
        echo "$val"
    done
}
