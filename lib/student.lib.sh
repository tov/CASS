# Library for printing out student info

email () {
    cat $COURSE_DB/students/$1/email
}

first () {
    if [ "$1" = '-' ]; then
        sed 's/ .*//' $COURSE_DB/students/$2/first
    else
        cat $COURSE_DB/students/$1/first
    fi
}

last () {
    cat $COURSE_DB/students/$1/last
}

call_me () {
    cat $COURSE_DB/students/$1/call-me
}

name () {
    echo `first $1; last $1`
}

called () {
    call_me $1 || name $1
}

canvasid () {
    cat $COURSE_VAR/students/$1/canvasid
}

githubid () {
    cat $COURSE_DB/students/$1/githubid
}

resolve_student () {
    find_single "student matching $1" $(resolve_student_helper "$1")
}

resolve_student_helper () (
    cd "$COURSE_VAR/students"

    for dir in *; do
        if cat $dir/* | tr '\n' ' ' | grep -i -q "$1"; then
            basename "$dir"
        fi
    done
)

find_student_by_name () {
    eval "$(getargs + last first)"

    find_single "student $first $last" \
        $(filter_students_by_name "$last" "$first")
}

filter_students_by_name () {
    eval "$(getargs + last first)"
    local pattern

    first=$(echo "$first" | sed 's/[^A-Za-z].*//')
    last=$(echo "$last" | sed 's/[^A-Za-z].*//')
    pattern=":$last.*,$first"

    all_netids |
        while read netid; do
            echo "$netid:$(last $netid),$(first $netid)"
        done |
        grep -i -E "$pattern" |
        sed 's/:.*//'
}
