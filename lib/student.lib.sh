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

print_student_property_short () {
    local value; value=$(print_student_property $1 "$2")
    printf %s "${value%% *}"
}

get_student_property () {
    if [ $# = 2 ]; then
        print_student_property $1 "$2"
    elif [ "$1" = - ]; then
        print_student_property_short "$2" "$3"
    elif [ "$2" = - ]; then
        print_student_property $1 "$3"
    elif [ "$3" = - ]; then
        print_student_property $1 "$2"
    else
        print_student_property $1 "$2"
    fi
}

get_student_property_long () {
    [ "$1" != - ] || shift
    print_student_property $1 $2
}

first () {
    get_student_property "$@" first
}

last () {
    get_student_property "$@" last
}

email () {
    get_student_property_long "$@" email
}

call_me () {
    get_student_property_long "$@" call-me
}

canvasid () {
    get_student_property_long "$@" canvasid
}

githubid () {
    get_student_property_long "$@" githubid
}

called () {
    call_me $1 2>/dev/null || first - $1
}

full_name () {
    printf '%s %s' "$(first "$@")" "$(last "$@")"
}

format_address () {
    printf '"%s" <%s>' "$(full_name "$@")" "$(email "$@")"
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
