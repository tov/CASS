#!/bin/sh

. "$(dirname "$0")/.CASS"
course_use canvasapi
course_use student

eval "$(getargs cmd ...)"

create_one () {
    eval "$(getargs + hw_num name1 name2)"

    netid1=$(resolve_student "$name1") || exit 1
    netid2=$(resolve_student "$name2") || exit 2
    user1_id=$(canvasid $netid1) || exit 3
    user2_id=$(canvasid $netid2) || exit 4
    name="$(first $netid1) & $(first $netid2)" || exit 5

    cat_id=$(canvas_api_find_group_cat $hw_num | jqid) || exit 6

    exec >&2
    printf "Creating group '$name'... "
    group=$(canvas_api_create_group $cat_id "$name") || exit 7
    group_id=$(printf %s "$group" | jqid) || exit 8
    printf "done, id=%s\n" $group_id

    printf "Adding user $netid1 ($user1_id)... "
    mem1_id=$(canvas_api_group_add_user $group_id $user1_id | jqid) || exit 9
    printf "done, id=%s.\n" $mem1_id

    printf "Adding user $netid2 ($user2_id)... "
    mem2_id=$(canvas_api_group_add_user $group_id $user2_id | jqid) || exit 10
    printf "done, id=%s.\n" $mem2_id
}

delete_one () {
    eval "$(getargs + group_id)"
    canvas_curl DELETE $(URI_group $group_id)
}

case "$cmd" in
    create)
        create_one "$@"
        ;;
    delete)
        delete_one "$@"
        ;;
    *)
        echo >&2 "$0: Unknown command: $cmd"
        exit 1
        ;;
esac
