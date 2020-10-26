#!/bin/sh

# Creates a web site for the given manual pages.

set -eu -o pipefail

main () {
    sorted_args "$@" | build_page > index.md
}

sorted_args () {
    printf '%s\n' "$@" |
        sed -E 's@^.*/([^/\t]*)$@\1\t&@' |
        sort -f |
        sed 's@^[^\t]*\t@@'
}

build_page () {
    cat <<....EOF
---
title: IPD Manual Pages
---

| Page  | Description |
| :---- | :---------- |
....EOF

    process_files
}

process_files () {
    while read file; do
        printf '| '
        process_file "$file"
        printf ' |\n'
    done
}

process_file () {
    original="$(basename "$1")"
    markdown="$(get_markdown "$1")"

    if [ "$markdown" = "$original" ]; then
        man_link "$markdown" "$original"
    else
        man_ref "$markdown" "$original"
    fi

    printf ' | '
    extract_apropos "$1"
}

man_link () {
    printf '[**%s**](%s)(%s)' \
        "$(man_title "$2")" \
        "$1" \
        "$(man_section "$2")"
}

man_ref () {
    printf '[*%s*](%s)(%s)' \
        "$(man_title "$2")" \
        "$1" \
        "$(man_section "$2")"
}

get_markdown () {
    if [ -L "$1" ]; then
        set -- "$(basename "$(readlink "$1")")"
    else
        set -- "$(basename "$1")" "$1"
        pandoc -s "$2" -o "$1.md" || return
    fi

    puts "$1"
}

man_title () {
    puts "${1%.*}"
}

man_section () {
    puts "${1##*.}"
}

extract_apropos () {
    sed '/^\\- /{s///; q;}; d' "$1" | tr '\n' ' '
}

puts () {
    printf %s "$1"
}

#########
main "$@"
#########
