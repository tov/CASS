# Shell library for dealing with homeworks

find_local_repo () {
    eval "$(getargs + hw)"

    local result
    result=$(printf '%s/hw-dev/%02d' "$COURSE_ROOT" $hw)

    if [ -d "$result" ]; then
        echo "$result"
    else
        echo >&2 "Local repo for Homework $hw doesn’t exist"
        return 1
    fi
}

remote_starter_repo_name () {
    eval "$(getargs + hw)"
    printf '_hw%02d-starter' $hw
}

remote_starter_repo_url () {
    eval "$(getargs + hw)"
    echo "$git_base/$(remote_starter_repo_name $hw).git"
}
