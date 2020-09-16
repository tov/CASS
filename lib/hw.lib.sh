# Shell library for dealing with assignments

: ${assignment_slug_fmt:=hw%02d}
: ${assignment_called:=Homework}

find_local_repo () {
    eval "$(getargs + hw)"

    local result
    result=$(printf '%s/hw-dev/%02d' "$COURSE_ROOT" $hw)

    if [ -d "$result" ]; then
        echo "$result"
    else
        echo >&2 "Local repo for ${assignment_called} $hw doesn’t exist"
        return 1
    fi
}

remote_starter_repo_name () {
    printf "_${assignment_slug_fmt}-starter" $1
}

remote_starter_repo_url () {
    printf "%s/_${assignment_slug_fmt}-starter.git" "$git_base" $1
}

remote_hw_dev_repo_name () {
    printf "_${assignment_slug_fmt}-dev" $1
}

remote_hw_dev_repo_url () {
    printf "%s/_${assignment_slug_fmt}-dev.git" "$git_base" $1
}
