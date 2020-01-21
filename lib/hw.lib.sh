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
    printf '_hw%02d-starter' $1
}

remote_starter_repo_url () {
    printf '%s/_hw%02d-starter.git' "$git_base" $1
}

remote_hw_dev_repo_name () {
    printf '_hw%02d-dev' $1
}

remote_hw_dev_repo_url () {
    printf '%s/_hw%02d-dev.git' "$git_base" $1
}
