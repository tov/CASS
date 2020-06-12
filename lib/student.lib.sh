# Library for printing out student info

format_list () {
    local each;    each=$1; shift
    local between; between=$1; shift
    local argc0;   argc0=$#
    while [ $# -gt 1 ]; do
        $each "$1"
        shift
        ARGC=$# ARGC0=$argc0 $between
    done
    $each "$1"
}

sep_comma_and () {
    if [ "$ARGC0" = 2 ]; then
        printf ' and '
    elif [ "$ARGC" = 1 ]; then
        printf ', and '
    else
        printf ', '
    fi
}

email () {
    print_student_property $1 email
}

first () {
    if [ "$1" = '-' ]; then
        print_student_property $2 first | sed 's/ .*//' | tr -d '\n'
    else
        print_student_property $1 first
    fi
}

last () {
    print_student_property $1 last
}

call_me () {
    print_student_property $1 call-me
}

canvasid () {
    print_student_property $1 canvasid
}

githubid () {
    print_student_property $1 githubid
}

full_name () {
    printf '%s %s' "$(first $1)" "$(last $1)"
}

called () {
    call_me $1 2>/dev/null || first - $1
}

format_address () {
    printf '"%s" <%s>' "$(full_name $1)" "$(email $1)"
}

email_list () {
    format_list email 'printf \x20' "$@"
}

greeting_list () {
    format_list called sep_comma_and "$@"
}

format_to_line () {
    format_list format_address 'printf ,\x20' "$@"
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

    all_netids |
        while read netid; do
            echo "$netid:$(last $netid),$(first $netid)"
        done |
        grep -i -E "$pattern" |
        sed 's/:.*//'
}
