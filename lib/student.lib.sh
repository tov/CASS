# Library for printing out student info

alias puts='printf %s'

###
### PROPERTY GETTERS
###

first () {
    get_student_property "$1" first
}

last () {
    get_student_property "$1" last
}

email () {
    get_student_property "$1" email
}

call_me () {
    get_student_property "$1" call-me
}

canvasid () {
    get_student_property "$1" canvasid
}

githubid () {
    get_student_property "$1" githubid
}


###
### PROPERTY LOOKUP HELPERS
###

# $1 – netid
# $2 – propname
# ENV[PROPSTYLE] ::= SHORT | ''
# ENV[ERRSTYLE]  ::= NAME | ''
# ENV[ERRCODE]   ::= int | ''
get_student_property () {
    local netid=${1:?need NETID} || return 10
    local propname=${2:?need PROPNAME} || return 10

    local userpath="$(get_student_property_dir "$netid")" ||
        return ${ERRCODE-1}

    local filepath="$userpath"/$propname

    if ! [ -e "$filepath" ]; then
        no_such_property_message $netid $propname >&2
        return ${ERRSTYLE-2}
    fi

    format_property_value "$filepath"
}

get_student_property_dir () {
    local userpath="$COURSE_ROSTER"/$1

    if ! [ -e "$userpath" ]; then
        no_such_student_message $netid >&2
        return 1
    fi

    puts "$userpath"
}

format_property_value () {
    if [ "${PROPSTYLE-}" != SHORT ]; then
        cat "$1"
    else
        set -- $(head -1 "$1") || return
        puts "${1-}"
    fi
}

no_such_student_message () {
    printf "$(no_such_student_message_format)" "$@"
}

no_such_property_message () {
    printf "$(no_such_property_message_format)" "$@"
}

no_such_student_message_format () {
    case ${ERRSTYLE-} in
        (NAME) puts %s ;;
        (*)    puts 'no such student: %s\n' ;;
    esac
}

no_such_property_message_format () {
    case ${ERRSTYLE-} in
        (NAME) puts %s.%s ;;
        (*)    puts '%s: no such property: %s\n' ;;
    esac
}

###
### SYNTHETIC PROPERTIES
###

synth_prop () {
    local netid=${1:?need NETID} || return 10
    local propname=${2:?need PROPNAME} || return 10
    shift; shift

    get_student_property_dir $netid 1>/dev/null ||
        return ${ERRCODE-1}

    ERRSTYLE=NAME ERRCODE=0 eval printf "$@"
}

full_name () {
    synth_prop "$1" full_name \
        '"%s %s" "$(first '"$1"')" "$(last '"$1"')"'
}

full_called () {
    synth_prop "$1" full_called \
        '"%s %s" "$(called '"$1"')" "$(short_last '"$1"')"'
}

called () {
    call_me "$1" 2>/dev/null ||
        "${2:-short_first}" "$1"
}

short_first () {
    PROPSTYLE=${PROPSTYLE-SHORT} first "$1"
}

short_last () {
    PROPSTYLE=${PROPSTYLE-SHORT} last "$1"
}

email_list () {
    format_list email 'printf \x20' "$@"
}

greeting_list () {
    format_list called _sep_comma_and "$@"
}

format_to_line () {
    format_list format_address 'printf ,\x20' "$@"
}

format_address () {
    printf '"%s" <%s>' "$(full_name "$1")" "$(email "$1")"
}

format_list () {
    local each;    each="$1"; shift
    local between; between="$1"; shift
    local argc0;   argc0=$#
    while [ $# -gt 1 ]; do
        $each "$1"
        shift
        ARGC=$# ARGC0=$argc0 $between
    done
    $each "$1"
}

_sep_comma_and () {
    case $ARGC0,$ARGC in
        (2,*) printf ' and ' ;;
        (*,1) printf ', and ' ;;
        (*)   printf ', ' ;;
    esac
}


###
### SEARCHING
###

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
