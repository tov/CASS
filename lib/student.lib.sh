# Library for printing out student info

alias puts='printf %s'

###
### PROPERTY GETTERS
###

first () {
    get_student_property "$1" first -name
}

last () {
    get_student_property "$1" last -name
}

email () {
    get_student_property "$1" email -email
}

call_me () {
    get_student_property "$1" call-me -name
}

canvasid () {
    get_student_property "$1" canvasid -id
}

githubid () {
    get_student_property "$1" githubid -id
}


###
### PROPERTY LOOKUP HELPERS
###

# $1 – netid
# $2 – propname
# ENV[PROPSTYLE] ::= [FULL] | SHORT
# ENV[ERRSTYLE]  ::= [MESSAGE] | NAME | BLANK | {format-string}
# ENV[ERRCODE]   ::= [1] | int
get_student_property () {
    local netid=${1:?need NETID} || return 10
    local propname=${2:?need PROPNAME} || return 10

    local userpath="$(get_student_property_dir "$netid")" ||
        return ${ERRCODE-1}

    local filepath="$userpath"/$propname

    if ! [ -e "$filepath" ]; then
        no_such_property_message $netid $propname >&2
        return ${ERRCODE-2}
    fi

    style_prop_value "${PROPSTYLE:-FULL},${3-}" \
        cat "$filepath"
}

style_prop_value () {
    local prop_style=$1; shift
    case $prop_style in
        (SHORT,-name)
            "$@" | sed -E 's/[[:space:]].*//; q' | tr -d '\n'
            ;;
        (SHORT,-email)
            "$@" |
                sed -E 's|[.]northwestern[.]edu$||' | tr -d '\n'
            ;;
        (*)
            "$@"
            ;;
    esac
}

get_student_property_dir () {
    local userpath="$COURSE_ROSTER"/$1

    if ! [ -e "$userpath" ]; then
        no_such_student_message $netid >&2
        return 1
    fi

    puts "$userpath"
}

no_such_student_message () {
    printf "$(no_such_student_message_format)" "$@"
}

no_such_property_message () {
    printf "$(no_such_property_message_format)" "$@"
}

no_such_student_message_format () {
    case ${ERRSTYLE:-MESSAGE} in
        (BLANK)   ;;
        (MESSAGE) puts 'no such student: %s\n';;
        (NAME)    puts %s;;
        (*)       puts ${ERRSTYLE};;
    esac
}

no_such_property_message_format () {
    case ${ERRSTYLE:-MESSAGE} in
        (BLANK)   ;;
        (MESSAGE) puts '%s: no such property: %s\n';;
        (NAME)    puts %s.%s;;
        (*)       puts ${ERRSTYLE};;
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
    PROPSTYLE=SHORT first "$1"
}

short_last () {
    PROPSTYLE=SHORT last "$1"
}

email_list () {
    format_list email _put_space "$@"
}

greeting_list () {
    format_list called _sep_comma_and "$@"
}

format_to_line () {
    format_list format_address '_put_comma _put_space' "$@"
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

_put_then () {
    printf "$1"; shift
    "$@"
}

_put_comma () {
    _put_then , "$@"
}

_put_semi () {
    _put_then \; "$@"
}

_put_space () {
    _put_then ' ' "$@"
}

_sep_comma_and () {
    case $ARGC0,$ARGC in
        (2,*) printf ' %s ' "${AND_SYMBOL:-and}" ;;
        (*,1) printf ', %s ' "${AND_SYMBOL:-and}" ;;
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
