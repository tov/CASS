#!/bin/sh

# Usage: find_similar_code.sh HW FILEPATH SEDEXPR TMPDIR
#
# Uses sed script SEDEXPR to extract code from a file named FILEPATH in
# every Homework HW submission that has it. Strips comments and blank
# lines, finds code that matches exactly, and outputs a summary in
# Markdown. Uses TMPDIR for temporary files (which can be useful to
# inspect).

. "$(dirname "$0")/.CASS"
course_use find

main () {
    eval "$(getargs hw filepath sedexpr tmpdir=)"

    if [ -z "$tmpdir" ]; then
        tmpdir=$(mktemp -d "$(basename $0 .sh)-XXXXX")
        trap 'rm -Rf "$tmpdir"' EXIT
    fi

    extract_original "$tmpdir"/original $(list_submitters $hw)
    strip_comments "$tmpdir"/stripped "$tmpdir"/original
    sort_group_and_format "$tmpdir"/stripped format_md_code cxx
}

format_md_code () {
    local lang=$1 netid=$2 code="$3"
    printf "%s:\n\n${MD_BACKTICKS}%s\n${code}${MD_BACKTICKS}\n\n" \
        "$netid" "$lang"
}
MD_BACKTICKS='`````'

extract_original () {
    local dstdir="$1"; shift
    local netid src dst

    rm -Rf "$dstdir"
    mkdir -p "$dstdir"

    for netid; do
        src=$(find_team_repo $hw $netid)/.cache/$filepath
        test -e "$src" || continue

        dst="$dstdir/$netid-$(basename "$src")"
        sed -E "$sedexpr" <"$src" >"$dst"
    done
}

strip_comments () {
    local dstdir="$1" srcdir="$2"
    local src base netid dst

    rm -Rf "$dstdir"
    mkdir -p "$dstdir"

    for src in "$srcdir"/*; do
        base=${src##*/}
        netid=${base%%-*}
        dst="$dstdir/$base"
        sed -E 's@ *//.*@@; /^ *$/d' <"$src" >"$dst"
    done
}

sort_group_and_format () {
    local srcdir="$1"; shift
    load_and_sort_code "$srcdir" | group_sorted_code "$@"
}

load_and_sort_code () {
    local srcdir="$1"
    local src base netid

    for src in "$srcdir"/*; do
        base=${src##*/}
        netid=${base%%-*}

        printf '%-8s  ' "$netid"
        sed <"$src" -E '
            s/[%\\]/&&/g
            s/\t/\\t/g
            s/$/\\n/
        ' | tr -d '\n'
        printf '\n'
    done | sort -k2 -k1
}

group_sorted_code () (
    read -r netid code

    while read -r next_netid next_code; do
        if [ "$code" = "$next_code" ]; then
            netid="$netid, $next_netid"
            continue
        fi

        "$@" "$netid" "$code"

        netid=$next_netid code="$next_code"
    done

    "$@" "$netid" "$code"
)

#########
main "$@"
#########

