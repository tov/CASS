# Common definitions course admin shell scripts

# Exit on errors, including errors in piped subshells
set -eo pipefail

course_used_vars=:

course_use () {
    local each
    for each; do
        case "$course_used_vars" in
            *:$each:*) continue ;;
        esac

        if [ -f "$COURSE_LIB/$each.lib.sh" ]; then
            . "$COURSE_LIB/$each.lib.sh"
        else
            . "$course_cass/lib/$each.lib.sh"
        fi

        course_used_vars=${course_used_vars}${each}:
    done
}

course_load_var () {
    local var
    local file

    var="$1"
    file="$COURSE_ETC/$2"

    if [ -f "$file" ]; then
        eval "$var=\$(cat \"$file\"); export $var"
    fi
}

course_eval_env () {
    eval "$(sed <"$1" -E '
        s/^[[:space:]]*//
        /^(#|$)/bdone
        /^([_[:alpha:]][_[:alnum:]]*)=(.*)$/{
            s//\1=\2; export \1/
            bdone
        }
        s/.*/printf >\&2 '\''What?: %s\\n'\'' '\''&'\''/
        :done
    ')"
}

course_init_env () {
    if [ -d "$COURSE_ROOT/private" ]; then
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
    export COURSE_VAR

    . "$COURSE_ETC/config.sh"

    local i
    for i in "$COURSE_ETC"/*.env; do
        course_eval_env "$i"
    done
}

CASS_on_exit_list=
CASS_on_exit () {
    if [ -n "${2-}" ]; then
        echo >&4 "$0: got SIG$2, shutting down"
    fi

    for cmd in $CASS_on_exit_list; do
        $cmd ||
            echo >&4 "CASS_on_exit: $cmd returned $?"
    done
    CASS_on_exit_list=

    if [ -n "${1-}" ]; then
        exit $1
    fi
}

trap CASS_on_exit               EXIT
trap 'CASS_on_exit 130 INT'     INT
trap 'CASS_on_exit 131 QUIT'    QUIT

register_exit_function () {
    set -- $CASS_on_exit_list $*
    CASS_on_exit_list=$*
}

bc_expr () {
    echo "$*" | bc -l
}

bc_cond () {
    test "$(bc_expr "$*")" = 1
}

assert () {
    local code
    local msg

    case "$1" in
        -*)
            code=${1#-}; shift
            ;;
        *)
            code=1
            ;;
    esac

    msg=$1; shift

    if ! "$@"; then
        echo >&4 "$msg"
        return $code
    fi
}

find_single () {
    eval "$(getargs + description ...)"

    if [ -z "${1-}" ] || [ -n "${2-}" ]; then
        printf "Cannot resolve %s\n" "$description" >&4
        printf "Candidates were: %s\n" "$*" | fmt   >&4
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
                echo "local $1; $1=${2-}"
            }
            ;;
        *)
            cmd=$0
            define_var () {
                echo "$1=${2-}"
            }
            ;;
    esac

    flags=
    while expr "Z${1-}" : Z- >/dev/null; do
        flags=$flags${1#-}
        shift
    done

    ARGS=$(printf %s "$*" | tr a-z A-Z)
    if [ -n "${cmd-}" ]; then
        cmd_usage="Usage: $cmd${flags:+ -$flags} $ARGS"
    else
        cmd_usage="$0: bad shell call (context: -$flags $ARGS)"
    fi

    BAIL () {
        local i; i=$1; shift
        local result; result=$1; shift
        echo "${i}echo>&4 '$cmd_usage'"
        local line
        for line in "$@"; do
            echo "${i}echo>&4 \"$line\""
        done
        echo "${i}exit $result"
    }

    if [ -n "$flags" ]; then
        define_var actual_given_flag
        local exploded; exploded=$(explode_words $flags)
        for flag in $exploded; do
            define_var flag_$flag
        done
        echo 'while [ $# -gt 0 ]; do'
        echo '  case "$1" in'
        echo '    --) shift; break;;'
        echo '    -)  break;;'
        echo '    -*)'
        echo '      for actual_given_flag in $(explode_words ${1#-}); do'
        echo '        case "$actual_given_flag" in'
        for flag in $exploded; do
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
            ?*=*)
                echo 'if [ $# = 0 ]; then'
                    define_var ${arg%%=*} ${argv#*=}
                echo 'else'
                    define_var ${arg%%=*} '$1'
                echo '  shift'
                echo 'fi'
                ;;
            *)
                echo 'if [ $# = 0 ]; then'
                printf '  missing="$missing %s"\n' $(echo $arg | tr a-z A-Z)
                echo 'else'
                    define_var $arg '$1'
                echo '  shift'
                echo 'fi'
                ;;
        esac
    done

    echo 'if [ -n "$missing" ]; then'
    BAIL '  ' 3 'Missing arguments:$missing'
    echo 'fi'

    if ! $dotted; then
        echo 'if ! [ $# = 0 ]; then'
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
    char=$char$char$char
    fmt='\n%s\n%s '$fmt' %s\n%s\n'
    printf "$fmt" "$char" "$char" "$@" "$char" "$char"
}

team_members () {
    echo "$*" | sed 's/-/ /g'
}

all_netids () (
    cd "$COURSE_DB/students"
    ls
)

netid_exists () {
    test -n "$1" &&
        test -d "$COURSE_DB/students/$1"
}

find_single () {
    eval "$(getargs + description ...)"

    if [ $# != 1 ]; then
        printf "Cannot resolve %s\n" "$description" >&4
        printf "Candidates were: %s\n" "$*" | fmt   >&4
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

    arg=$1
    while [ -n "$arg" ]; do
        case "$arg" in
            -q)
                flag_q=1
                shift; arg=$1
                ;;
            -1)
                flag_1=1
                shift; arg=$1
                ;;
            -q*)
                flag_q=1
                arg=-${arg#-q}
                ;;
            -1*)
                flag_1=1
                arg=-${arg#-1}
                ;;
            *)
                break
                ;;
        esac
    done

    regexp=$1

    if ! netid=$(find_netid "$regexp" 4>/dev/null); then
        netid=$(find_netids_by_info "$regexp" 4>/dev/null) || true

        if [ -n "$flag_1" ]; then
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
        fi >&4
    fi

    for netid in $netid; do
        if [ -n "$flag_q" ]; then
            printf '%s\n' $netid
        else
            print_student_info -n $netid
        fi
    done
}

resolve_student () {
    case "$1" in
        -C) # Don't check
            echo "$2"
            ;;
        -R) # Check but don't search
            assert "NetID doesn't exist: $2" netid_exists "$2" &&
            echo "$2"
            ;;
        *)  # Search
            find_student -1q "$@"
            ;;
    esac
}

print_student_property () {
    cat "$COURSE_DB"/students/$1/$2
}

print_student_info () {
    if [ "$1" = -n ]; then
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

    if [ "$result" = 0 ]; then
        echo ' okay.'
    else
        echo ' FAILED.'
    fi

    return $result
}

ref_exists () {
    git rev-parse --verify "$1" >/dev/null 2>&1
}

cass_fatal () {
    local errcode; errcode=$1; shift
    echo >&4 "$(short_prog_name): fatal error (#$errcode): $*"
    exit $errcode
}

cass_error () {
    local errcode; errcode=$1; shift ||
        cass_fatal 101 'cass_error needs arguments'
    echo >&4 "$(short_prog_name): error (#$errcode): $*"
    return $errcode
}

list_submitters () {
    local hw; hw=$1; shift

    local sort_flags
    if (( $hw % 2 == 0 )); then
        sort_flags=-r
    else
        sort_flags=
    fi

    gsc admin submissions hw$hw                |
        awk '$2 ~ /[[:alnum:]]+/ {print $2}'   |
        sort $sort_flags
}

get_line_indent () {
    printf '%s' "$1" | expand | sed 's/[^ ].*//' | tr -d '\n'
}

unindent () {
    local line
    local script

    line=$(head -1)
    script="s/^$(get_line_indent "$line")//;$1"

    {
        printf '%s\n' "$line"
        cat
    } | expand | ubsed -E "$script"
}

short_prog_name () {
    local full; full=${1-$0}
    local base; base=${full##*/}

    if [ "$COURSE_BIN/$base" = "$full" ] ||
       [ "$(which "$base" 2>/dev/null)" = "$full" ];
    then
        printf %s "$base"
    else
        printf %s "$full"
    fi
}

sed_has_unbuffered () {
    "$1" --unbuffered '' </dev/null
}

sed_has_l_flag () {
    "$1" -l '' </dev/null
}

date_has_pctN () {
    case "$($1 +%N)" in
        *N) false;;
        *)  true;;
    esac
}

find_unbuffered_sed () {
    local candidate
    for candidate; do
        candidate=$(which $candidate) || continue
        if sed_has_unbuffered $candidate; then
            UNBUFFERED_SED="$candidate --unbuffered"
            return 0
        elif sed_has_l_flag $candidate; then
            UNBUFFERED_SED="$candidate -l"
            return 0
        fi
    done

    cass_error 17 'could not find sed with unbuffered option'
}

find_pctN_date () {
    local candidate
    for candidate; do
        candidate=$(which $candidate) || continue
        if date_has_pctN $candidate; then
            PCT_N_DATE=$candidate
            return 0
        fi
    done

    cass_error 18 'could not find date with %N support'
}

find_unbuffered_sed gsed sed
ubsed () {
    $UNBUFFERED_SED "$@"
}

find_pctN_date gdate date
date () {
    $PCT_N_DATE "$@"$gnu_date
}
