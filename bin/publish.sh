#!/bin/sh

. "$(dirname "$0")/.CASS"

eval "$(getargs -v src dst)"

eval_publish () {
    local dir; dir=$1

    cat "$dir/Publish"                  |
        sed '/^[[:space:]]*#/d;
             /^[[:space:]]*$/d;
             s/^/ls -d /'               |
            (cd "$dir"; sh)             |
            sort                        |
            uniq
}

log () {
    test -z "$flag_v" && return
    printf "$@" >&2
    echo >&2
}

make_q () {
    if [[ -f "$1/Makefile" ]]; then
        make -C "$1" -j6 $2 |
            egrep -v '^make: (?:Nothing to be done for .*|.* is up to date)' ||
            true
    fi
}

filter_comments () {
    sed '
        /^[[:space:]]*#/d
        /^[[:space:]]*$/d
    ' "$@"
}

eval_publish () {
    local dir; dir=$1

    filter_comments "$dir/Publish" | (
        cd "$dir"
        while read line; do
            ls -d "$line"
        done
    ) | sort | uniq
}

publish_dir () (
    local src; src=$1; shift
    local dst; dst=$1; shift
    indent="$*"

    log "${indent}Publishing: ‘%s’ to ‘%s’" "$src" "$dst"

    if [[ -f "$src"/Publish ]]; then
        make_q "$src" Publish

        log "${indent}Evaluating: $src/Publish"
        eval_publish "$src" | while read entry
        do
            log "${indent} - Copying: ‘%s’" "$src/$entry"
            mkdir -p "$dst/$(dirname "$entry")"
            make_q "$src" "$entry"
            cp -RL "$src/$entry" "$dst/$(dirname "$entry")"
        done
    fi

    ls "$src" | while read entry
    do
        if [[ -d "$src/$entry" ]]; then
            publish_dir "$src/$entry" "$dst/$entry" "$indent  "
        fi
    done
)

if [[ -d "$src" ]]; then
    publish_dir "$src" "$dst"
else
    echo>&2 "$(basename "$0"): Don’t know what to do with ‘$src’"
    exit 2
fi
