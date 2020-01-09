#!/bin/sh

set -eo pipefail

. "$(dirname "$0")/.CASS"
course_use canvasapi

eval "$(getargs cmd ...)"

list_em () {
    eval "$(getargs +)"
    canvas_curl GET $(URI_course_group_categories) |
        jq -r '.[] | .name + "\t" + (.id | tostring)' |
        sort
}

show_it () {
    eval "$(getargs + hw_num)"

    local cat
    local cat_name
    local cat_id

    cat=$(canvas_api_find_group_cat $hw_num)
    cat_name=$(printf %s "$cat" | jq -r .name)
    cat_id=$(printf %s "$cat" | jqid)

    printf '%s (%d)\n\n' "$cat_name" "$cat_id"
    canvas_curl GET $(URI_group_category_groups $cat_id) |
        jq -r '.[] | .name'
}

delete_it () {
    eval "$(getargs + hw_num)"

    local cat_id
    cat_id=$(canvas_api_find_group_cat $hw_num | jqid) || exit 2

    canvas_curl DELETE $(URI_group_category $cat_id) | jq .
}

create_one () {
    eval "$(getargs + hw_num)"
    canvas_api_create_group_cat "HW$hw_num pairs" | jq .
}

case "$cmd" in
    list)
        list_em "$@"
        ;;
    show)
        show_it "$@"
        ;;
    create)
        create_one "$@"
        ;;
    delete)
        delete_it "$@"
        ;;
    *)
        echo >&2 "$0: Unknown command: $cmd"
        exit 1
        ;;
esac
