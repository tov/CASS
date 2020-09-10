# Library for accessing Canvas from the shell

course_load_var CANVAS_OAUTH canvas_oauth.secret

course_use quote

canvas_api_course=$canvas_api/courses/$canvas_course_id

canvas_curl () {
    local maybe
    local token
    local uri

    if [ "$1" = --dry-run ]; then
        shift
        maybe=shell_quote_words
        token='<OAUTH_TOKEN>'
    elif [ -n "$CANVAS_OAUTH" ]; then
        maybe=
        token=$CANVAS_OAUTH
    else
        echo >&2 "$0: CANVAS_OAUTH not set"
        return 1
    fi

    eval "$(getargs + verb path ...)"

    verb=$(printf %s "$verb" | tr a-z A-Z)

    case "$path" in
        https://*)
            uri=$path
            ;;
        c/*)
            uri=$canvas_api_course/${path#c/}
            ;;
        /*)
            uri=$canvas_api$path
            ;;
        *)
            uri=$canvas_api/$path
            ;;
    esac

    $maybe curl --silent --request "$verb" \
        --header "Authorization: Bearer $token" \
        "$@" "$uri"
}

jqid () {
    jq -r .id
}

## URIs

join_uri () {
    echo "$*" | tr ' ' /
}

URI_user_group_categories () {
    join_uri $canvas_api group_categories
}

URI_course_group_categories () {
    join_uri $canvas_api_course group_categories
}

URI_group_category () {
    join_uri "$(URI_user_group_categories)" $1
}

URI_group_category_groups () {
    join_uri "$(URI_group_category $1)" groups
}

URI_group () {
    join_uri $canvas_api groups $1
}

URI_group_membership () {
    join_uri $(URI_group $1) memberships
}


## Requests

canvas_api_create_group_cat () {
    eval "$(getargs + name)"
    canvas_curl POST $(URI_course_group_categories) \
        -F "name=$name" \
        -F "self_signup=restricted" \
        -F "group_limit=2"
}

canvas_api_find_group_cat () {
    eval "$(getargs + hw_num)"

    local query
    query=$(cat <<-....EOF
	.[] | if .name | test("hw0*$hw_num"; "i") then
	    .
	else
	    empty
	end
....EOF
    )

    local result
    result=$(
        canvas_curl GET $(URI_course_group_categories) |
        jq -r "$query"
    ) || return 1

    if [ -n "$result" ]; then
        printf %s "$result"
    else
        echo >&2 "Cannot find group for HW $hw_num"
        return 2
    fi
}

canvas_api_create_group () {
    eval "$(getargs + cat_id name)"

    canvas_curl \
        POST $(URI_group_category_groups $cat_id) \
        -F "name=$name" \
        -F "self_signup=restricted" \
        -F "group_limit=2"
}

canvas_api_group_add_user () {
    eval "$(getargs + group_id user_id)"

    canvas_curl \
        POST $(URI_group_membership $group_id) \
        -F "user_id=$user_id"
}

canvas_api_delete_group () {
    eval "$(getargs + group_id)"

    canvas_curl \
        POST $(URI_group_category_groups $cat_id) \
        -F "name=$name" \
        -F "self_signup=restricted" \
        -F "group_limit=2"
}
