#!/bin/sh

. "$(dirname "$0")/../lib/common.sh"

eval "$(getargs -v src dst)"

log () {
    test -z "$flag_v" && return
    printf "$@" >&2
    echo >&2
}

make_q () {
    eval "$(getargs + dir target)"
    make -C "$dir" "$target" |
        grep -v '^make: \(Nothing to be done for .*\|.* is up to date\)\.'
}

eval_publish () {
    eval "$(getargs + dir)"

    cat "$dir/Publish"                  |
        sed '/^[[:space:]]*#/d;
             /^[[:space:]]*$/d;
             s/^/ls -d /'               |
            (cd "$dir"; sh)             |
            sort                        |
            uniq
}

publish_dir () (
    eval "$(getargs src dst ...)"
    indent="$*"

    log "${indent}Publishing: ‘%s’ to ‘%s’" "$src" "$dst"

    if [ -f "$src"/Publish ]; then
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
        if [ -d "$src/$entry" ]; then
            publish_dir "$src/$entry" "$dst/$entry" "$indent  "
        fi
    done
)

if [ -d "$src" ]; then
    publish_dir "$src" "$dst"
else
    echo>&2 "$(basename "$0"): Don’t know what to do with ‘$src’"
    exit 2
fi
