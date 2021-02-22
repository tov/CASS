#!/bin/sh

# Downloads all homework submissions from a Canvas course.

set -eu
. "$(dirname "$0")/.CASS"
eval "$(getargs course_id asst_name= out_dir=)"

export CANVAS_COURSE_ID=${course_id}
course_use canvasapi

if [ -z "$out_dir" ]; then
    out_dir=course_${course_id}
fi

tab_char="$(printf '\t')"


main () {
    local id name
    list_assignments | while read id name; do
        get_submissions_for_assignment "$id" "$name"
    done
}

get_submissions_for_assignment () {
    local asst_id="$1" asst_name="$2"
    local asst_dir="$(assignment_dir "$asst_name")"

    list_submissions "$asst_id" |
        while IFS="$tab_char" read user_id filename url; do
            src_dir="${asst_dir}/user_${user_id}/src"
            mkdir -p "$src_dir"
            echo "user_${user_id}: ${filename}"
            canvas_curl GET "$url" > "${src_dir}/${filename}"
        done
}

list_submissions () {
    canvas_api_list_submissions "$1" |
        jq -r '
            .[]
            | select(has("attachments"))
            | .user_id as $user_id
            | .attachments[]
            | [$user_id, .filename, .url]
            | @tsv
        '
}

list_assignments () {
    canvas_api_list_assignments $asst_name |
        jq -r '.[] | "\(.id) \(.name)"'
}

assignment_dir () {
    echo "${COURSE_VAR}/canvas_submissions/${out_dir}/$(clean_name "$1")"
}

clean_name () {
    echo "$*" | tr -sC '\na-zA-Z0-9_-' _
}

######
main #
######
