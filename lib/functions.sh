# Common definitions course admin shell scripts

set -o pipefail

find_course_root () {
    cd "$(dirname $0)"

    while ! [[ -f .root ]]; do
        if [[ "$(pwd)" = / ]]; then
            echo >&2 Could not find course root
            exit 3
        fi
        cd ..
    done

    pwd
}

course_use () {
    local each
    for each; do
        . "$COURSE_LIB/$each.lib.sh"
    done
}

course_load_var () {
    local var
    local file

    var="$1"
    file="$COURSE_ETC/$2"

    if [[ -f "$file" ]]; then
        eval "$var=\$(cat \"$file\"); export $var"
    fi
}

course_init_env () {
    COURSE_ROOT=$(find_course_root)

    if [[ -d "$COURSE_ROOT/private" ]]; then
        COURSE_PRIVATE=$COURSE_ROOT/private
    else
        COURSE_PRIVATE=$COURSE_ROOT
    fi

    COURSE_BIN=$COURSE_PRIVATE/bin
    COURSE_ETC=$COURSE_PRIVATE/etc
    COURSE_LIB=$COURSE_PRIVATE/lib
    COURSE_VAR=$COURSE_PRIVATE/var
    COURSE_DB="$COURSE_VAR/db"

    export COURSE_BIN
    export COURSE_DB
    export COURSE_ETC
    export COURSE_LIB
    export COURSE_PRIVATE
    export COURSE_ROOT
    export COURSE_VAR

    . "$COURSE_ETC/config.sh"
}

find_single () {
    eval "$(getargs + description ...)"

    if [[ -z "$1" ]] || [[ -n "$2" ]]; then
        printf "Cannot resolve %s\n" "$description" >&2
        printf "Candidates were: %s\n" "$*" | fmt   >&2
        exit 2
    fi

    printf '%s\n' "$1"
}

getargs () (
    usage='Usage: eval "$(getargs [+[CMD]] [-OPTS] ARGNAME... [[RESTNAME]...])"'

    case "$1" in
        --help|'')
            echo "$usage"
            return 0
            ;;
        '+'*)
            cmd=${1#+}; shift
            define_var () {
                echo "local $1; $1=$2"
            }
            ;;
        *)
            cmd=$0
            define_var () {
                echo "$1=$2"
            }
            ;;
    esac

    flags=
    while expr "Z$1" : Z- >/dev/null; do
        flags=$flags${1#-}
        shift
    done

    ARGS=$(printf '%s' "$*" | tr a-z A-Z)
    if [[ -n "$cmd" ]]; then
        cmd_usage="Usage: $cmd${flags+ -$flags} $ARGS"
    else
        cmd_usage="$0: bad shell call (context: -$flags $args)"
    fi

    BAIL () {
        local i; i=$1; shift
        local result; result=$1; shift
        echo "${i}echo>&2 '$cmd_usage'"
        local line
        for line in "$@"; do
            echo "${i}echo>&2 \"$line\""
        done
        echo "${i}exit $result"
    }

    if [[ -n "$flags" ]]; then
        define_var actual_given_flag
        for flag in $(explode_words $flags); do
            define_var flag_$flag
        done
        echo 'while [[ -n "$1" ]]; do'
        echo '    true'
        echo '  case "$1" in'
        echo '    --) shift; break;;'
        echo '    -)  break;;'
        echo '    -*)'
        echo '      for actual_given_flag in $(explode_words ${1#-}); do'
        echo '        case "$actual_given_flag" in'
        for flag in $(explode_words $flags); do
            echo "          $flag) flag_$flag=-$flag ;;"
        done
        echo '          *)'
        BAIL '            ' 2 'Unknown flag: $1'
        echo '        esac'
        echo '      done'
        echo '      shift;;'
        echo '    *)  break;;'
        echo '  esac'
        echo 'done'
    fi

    define_var missing
    dotted=false
    for arg; do
        case "$arg" in
            ...)
                dotted=true
                break
                ;;
            *...)
                dotted=true
                define_var "${arg%...}" '$*'
                break
                ;;
            *)
                define_var $arg '$1'
                echo 'if [[ $# = 0 ]]; then'
                printf '  missing="$missing %s"\n' $(echo $arg | tr a-z A-Z)
                echo 'else'
                echo '  shift'
                echo 'fi'
                ;;
        esac
    done

    echo 'if [[ -n "$missing" ]]; then'
    BAIL '  ' 3 'Missing arguments:$missing'
    echo 'fi'

    if ! $dotted; then
        echo 'if ! [[ $# = 0 ]]; then'
        BAIL '  ' 4 'Extra arguments: ${@/#/\\n • }'
        echo 'fi'
    fi
)

### BEGIN helpers for getargs

explode_words () {
    echo "$*" | sed 's/./& /g'
}

dump_args () {
    local i
    for i in "$@"; do
        printf ' • ‘%s’\n' "$i"
    done
}

### END helpers for getargs

headingf () {
    eval "$(getargs + -s char fmt ...)"

    if [[ -n "$flag_s" ]]; then
        fmt="$char$char$char $fmt $char$char$char"
    fi

    local message
    message=$(printf -- "$fmt\n" "$@")

    echo
    echo "$message" | tr -C '\n' "$char"
    echo "$message"
    echo "$message" | tr -C '\n' "$char"
}

team_members () {
    echo "$*" | sed 's/-/ /g'
}

all_netids () {
    cd "$COURSE_DB/students"
    ls
}

find_single () {
    eval "$(getargs + description ...)"

    if [[ $# != 1 ]]; then
        printf "Cannot resolve %s\n" "$description" >&2
        printf "Candidates were: %s\n" "$*" | fmt   >&2
        exit 2
    fi

    printf '%s\n' "$1"
}

find_single_matching () {
    local description; description=$1; shift
    local pattern; pattern=$1; shift

    find_single "$description" $("$@" | egrep -i "$pattern")
}

find_netid () {
    find_single_matching "student: $1" "^$1" all_netids
}

find_netids_by_info () {
    egrep -il "$1" "$COURSE_DB"/students/*/* |
            sed 's@.*/students/@@;s@/.*@@' |
            sort |
            uniq
}

whitespace_for_find_student=$(printf '\r\n\t ')

# Finds student matching "$regexp"
find_student () {
    local arg
    local netid
    local regexp

    for arg; do
        case "$arg" in
            -q*)
                flag_q=1
                arg="-${arg#-q}"
                ;;
            -1*)
                flag_1=1
                arg="-${arg#-1}"
                ;;
            -|--)
                shift
                break
                ;;
            *)
                regexp=$arg
                break
                ;;
        esac
    done

    if ! netid=$(find_netid "$regexp" 2>/dev/null); then
        netid=$(find_netids_by_info "$regexp" 2>/dev/null)

        if [[ -n "$flag_1" ]]; then
            case "$netid" in
                '')
                    printf 'No match for ‘%s’.\n' "$regexp"
                    return 1
                ;;
                *[$whitespace_for_find_student]?*)
                    printf 'No unique match for ‘%s’. Candidates:\n' "$regexp"
                    for netid in $netid; do
                        print_student_info -n $netid | sed 's/^/ - /'
                    done
                    return 2
                ;;
            esac
        fi >&2
    fi

    for netid in $netid; do
        if [[ -n "$flag_q" ]]; then
            printf '%s\n' $netid
        else
            print_student_info -n $netid
        fi
    done
}

resolve_student () {
    find_student -q1 "$@"
}

print_student_property () {
    cat "$COURSE_DB"/students/$1/$2
}

print_student_info () {
    if [[ "$1" = -n ]]; then
        shift
        printf '%-10s ' "$1"
    fi

    printf '%s %s <%s>\n' \
        "$(print_student_property "$1" first)" \
        "$(print_student_property "$1" last)" \
        "$(print_student_property "$1" email)"
}

# This code may be dead.
resolve_team () {
    local hw; hw=$1
    local pattern; pattern=$2

    find_single_matching "team: $pattern" "\\<$pattern" \
            "$COURSE_BIN/all_teams.sh" $hw
}

search_and_replace () {
    local patt; patt="$1"; shift
    local repl; repl="$1"; shift
    local file

    for file; do
        ex - "$file" <<........EOF
            g/$patt/s^^$repl^g
            wq
........EOF
    done
}

show_progress () {
    local message; message=$1; shift
    local result

    printf '%s...' "$message"
    "$@" >/dev/null
    result=$?

    if [[ "$result" = 0 ]]; then
        echo ' okay.'
    else
        echo ' FAILED.'
    fi

    return $result
}

ref_exists () {
    git rev-parse --verify "$1" >/dev/null 2>&1
}
