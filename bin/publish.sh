#!/bin/sh

. "$(dirname "$0")/.CASS"

eval "$(getargs -v src dst)"

if [ -n "$flag_v" ]; then
    log () {
        printf "$@" >&2
    }
else
    log () { :; }
fi

eval_publish () (
    cd "$1"

    sed -E '/^[[:space:]]*(#|$)/d' Publish |
        while read line
            do ls -d $line
        done |
        sort |
        uniq
)

copy_rec () {
    mkdir -p "$2"
    cp -RL "$1" "$2"
}

publish_dir () (
    src=$1; shift
    dst=$1; shift
    ind="$*"

    if [[ -f "$src"/Publish ]]; then
        log '%sPublishing: ‘%s’ to ‘%s’\n' "$ind" "$src" "$dst"
        log '%s  Copying' "$ind"
        eval_publish "$src" | while read entry; do
            log ' %s' "$entry"
            copy_rec "$src/$entry" "$dst/$(dirname "$entry")"
        done
        log '.\n'
    fi

    ls "$src" | while read entry; do
        if [[ -d "$src/$entry" ]]; then
            publish_dir "$src/$entry" "$dst/$entry" "$ind  "
        fi
    done
)

if [[ -d "$src" ]]; then
    make -C "$src" -j6
    publish_dir "$src" "$dst"
else
    echo>&2 "$(basename "$0"): Don’t know what to do with ‘$src’"
    exit 2
fi
