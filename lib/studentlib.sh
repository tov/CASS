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

github () {
    cat $COURSE_DB/students/$1/github
}

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

    "$COURSE_BIN/all_students.sh" |
        while read netid; do
            echo "$netid:$(last $netid),$(first $netid)"
        done |
        grep -i -E "$pattern" |
        sed 's/:.*//'
}

