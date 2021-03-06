# Common definitions course admin shell scripts

# Exit on errors, including errors in piped subshells
set -eo pipefail

course_used_vars=:

course_use () {
    local each
    for each; do
        case "$course_used_vars" in
            *:$each:*) continue
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
    COURSE_DB=$COURSE_VAR/db
    COURSE_ROSTER=$COURSE_DB/students

    export COURSE_BIN
    export COURSE_DB
    export COURSE_ETC
    export COURSE_LIB
    export COURSE_PRIVATE
    export COURSE_ROSTER
    export COURSE_VAR

    . "$COURSE_ETC/config.sh"

    eval "$(
        find "$COURSE_ETC" \
            -type f -name '*.env' \
            -exec echo 'course_eval_env "{}"' \;
    )"
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
    local code= desc='assertion failed:'

    while [ $# -gt 1 ]; do
        case $1 in
            (-[0-9]*) code=${1#-};;
            (\[|\!)   break;;
            (--)      shift; break;;
            (-?)      set -- test "$@"; break;;
            (*)       desc="$desc $1";;
        esac
        shift
    done

    "$@" || {
        echo >&4 "$desc"
        return $code
    }
}

getargs () (
    set +x
    usage='Usage: eval "$(getargs [+[CMD]] [-OPTS] ARGNAME... [[RESTNAME]...[+]])"'

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

    ARGS=$(puts "$*" | tr a-z A-Z)
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
            echo "          $flag) flag_$flag=-$flag;;"
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
    min_rest=0
    max_rest=0
    for arg; do
        case "$arg" in
            ...)
                min_rest=0
                max_rest=
                break
                ;;
            *...)
                min_rest=0
                max_rest=
                define_var "${arg%...}" '$*'
                break
                ;;
            ...+)
                min_rest=1
                max_rest=
                break
                ;;
            *...+)
                min_rest=1
                max_rest=
                define_var "${arg%...}" '$*'
                break
                ;;
            ?*=*)
                echo 'if [ $# = 0 ]; then'
                    define_var ${arg%%=*} ${arg#*=}
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

    if [ -n "$min_rest" ]; then
        echo '_i='$min_rest
        echo 'if [ $# -lt $_i ]; then'
        BAIL '  ' 4 'Need $((_i - $#)) more argument(s)'
        echo 'fi'
    fi

    if [ -n "$max_rest" ]; then
        echo '_i='$max_rest
        echo 'if [ $# -gt $_i ]; then'
        echo '  while (( _i-- )); do shift; done'
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
        puts " • ‘${i}’\n"
    done
}

### END helpers for getargs

headingf () {
    local flag_s=
    if [ "${1-}" = -s ]; then
        flag_s=-s; shift
    fi

    local char="${1?char}"
    local char="${2?fmt}"
    shift 2

    char=$char$char$char
    fmt='\n%s\n%s '$fmt' %s\n%s\n'
    printf "$fmt" "$char" "$char" "$@" "$char" "$char"
}

team_members () {
    echo "$*" | sed 's/-/ /g'
}

all_netids () (
    cd "$COURSE_ROSTER"
    ls
)

netid_exists () {
    test -n "$1" -a -d "$COURSE_ROSTER/$1"
}

find_single () {
    local description="${1?description}"; shift

    if [ -z "${1-}" ] || [ -n "${2-}" ]; then
        echo>&4 "Cannot resolve $description"
        echo>&4 "Candidates were: %*" | fmt
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
    egrep -il "$1" "$COURSE_ROSTER"/*/* |
            sed 's@.*/students/@@;s@/.*@@' |
            sort |
            uniq
}

whitespace_for_find_student=$(printf '\r\n\t ')

# Finds student matching "$regexp"
find_student () {
    local print_info='print_student_info -n'
    local flag_quiet=false
    local flag_unique=false

    OPTIND=1
    local opt
    while getopts q1 opt; do
        case $opt in
            q) flag_quiet=true;;
            1) flag_unique=true;;
        esac
    done
    shift $((OPTIND - 1))
    OPTIND=1

    local regexp=$1

    local netid
    if ! netid=$(find_netid "$regexp" 4>/dev/null)
    then
        netid=$(find_netids_by_info "$regexp" 4>/dev/null) || true

        if $flag_unique
        then
            case $netid in
                '')
                    echo>&4 "No match for ‘${regexp}’."
                    return 1
                ;;

                *[$whitespace_for_find_student]?*)
                    echo>&4 "No unique match for ‘${regexp}’. Candidates:"
                    for netid in $netid
                    do
                        $print_info $netid
                    done | cat>&4 -n
                    return 2
                ;;
            esac
        fi
    fi

    if $flag_quiet
    then
        print_info=echo
    fi

    for netid in $netid
    do
        $print_info $netid
    done
}

resolve_student () {
    case "$1" in
        -C) # Don't check
            echo "$2"
            ;;
        -R) # Check but don't search
            assert -- netid_exists "$2" &&
            echo "$2"
            ;;
        *)  # Search
            find_student -1q "$@"
            ;;
    esac
}

print_student_property () {
    if cat "$COURSE_ROSTER"/$1/$2 2>/dev/null; then
        return
    fi

    if [ $# -ge 3 ]; then
        printf "$3" "$1" "$2"
        return
    fi

    cass_error 82 "no such student property: $1.$2" || return
}

print_student_info () {
    local flag_n
    local netid
    local pinned

    if [ "$1" = -n ]
    then
        flag_n=true
        shift
    else
        flag_n=false
    fi

    for netid
    do
        if [ -e "$COURSE_ROSTER"/$netid/.PIN ]
        then pinned="$(tput_wrap 'setaf 1' printf '#PIN')"
        else pinned=
        fi

        if test $netid = teststudent
        then
            pinned=
            if $flag_n
            then
                tput_wrap 'setaf 2' printf 'teststudent '
            fi
        elif $flag_n
        then
            printf '%-7s %s' "$netid" "${pinned:-    }"
        fi

        printf '  %s %s <%s>\n' \
            "$(print_student_property "$1" first)" \
            "$(print_student_property "$1" last)" \
            "$(print_student_property "$1" email)"
    done
}

tput_wrap () {
    local before=
    local after=
    local color=$1; shift

    if tty -s
    then
        case $color in
            (*/=)
                before=$(tput ${color%/=})
                ;;
            (*/*)
                before=$(tput ${color%%;*})
                after=$(tput ${color#*;})
                ;;
            (*)
                before=$(tput $color)
                after=$(tput sgr0)
        esac
    fi

    puts "$before"
    "$@"
    puts "$after"
}

puts () {
    printf %s "$*"
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

    puts "$message..."
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

_cass_error_putln () {
    { printf>&4 ''; } 2>/dev/null || exec 4>&2

    echo>&4 "$@" || exit 255
}

cass_fatal () {
    local errcode; errcode=$1; shift
    _cass_error_putln "$(short_prog_name): fatal error (#$errcode): $*"
    exit $errcode
}

cass_error () {
    local errcode; errcode=$1; shift ||
        cass_fatal 101 'cass_error needs arguments'
    _cass_error_putln "$(short_prog_name): error (#$errcode): $*"
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
    puts "$1" | expand | sed 's/[^ ].*//' | tr -d '\n'
}

unindent () {
    if [ "${1-}" = . ]; then
        sed -E 's/^[[:space:]]*[.]?//'
        return
    fi

    local line
    local indent

    while line=$(head -1); do
        if [ -n "$(puts "$line" | tr -d ' \n\t')" ]; then
            indent=$(get_line_indent "$line")
            break
        else
            echo
        fi
    done

    {
        puts "$line"
        cat
    } | expand | ubsed -E "s/^${indent}//;$1"
}

pluralize () {
    if [ "$1" = 1 ]; then
        puts "$2"
    else
        puts "${3-${2}s}"
    fi
}

short_prog_name () {
    local full; full=${1-$0}
    local base; base=${full##*/}

    if [ "$COURSE_BIN/$base" = "$full" ] ||
       [ "$(which "$base" 2>/dev/null)" = "$full" ];
    then
        puts "$base"
    else
        puts "$full"
    fi
}

dir_is_empty () {
    ! test -d "$1" ||
        find "$1" -maxdepth 0 -empty | read
}

sed_has_unbuffered () {
    "$1" --unbuffered '' </dev/null
}

sed_has_l_flag () {
    "$1" -l '' </dev/null
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
    done 2>/dev/null

    cass_error 17 'could not find sed with unbuffered option'
}

find_unbuffered_sed gsed sed
ubsed () {
    $UNBUFFERED_SED "$@"
}

date_is_gnu () {
    test "$($1 -d 01/20/2021 +%Y%m%d)" = 20210120
}

find_gnu_date () {
    local candidate
    for candidate; do
        candidate=$(which $candidate) || continue
        if date_is_gnu $candidate; then
            PCT_N_DATE=$candidate
            return 0
        fi
    done 2>/dev/null

    cass_error 18 'could not find GNU date'
}

find_gnu_date hdate gdate date
date () {
    $PCT_N_DATE "$@"
}

gdate () {
    $PCT_N_DATE "$@"
}

fmt () {
    init_gnu_fmt gfmt fmt &&
    fmt "$@"
}

FMT_BIN=
init_gnu_fmt () {
    local candidate
    for candidate; do
        if FMT_BIN="$(which $candidate)"
        then
            fmt () { "$FMT_BIN" "$@"; }
            return
        fi
    done 2>/dev/null

    cass_error 19 'could not find GNU fmt'
}

is_gnu_fmt () {
    local version
    version="$("$1" --version)" &&
        expr x"$version" : '.*GNU'
} >/dev/null 2>&1

bsd_stat_mtime_seconds () {
    "${STAT_BIN:-stat}" -f %m "$@"
}

gnu_stat_mtime_seconds () {
    "${STAT_BIN:-stat}" --format=%Y "$@"
}

no_good_stat_mtime_seconds () {
    cass_error 80 'Could not find suitable stat(1)'
}

if gnu_stat_mtime_seconds . >/dev/null 2>&1; then
    alias stat_mtime_seconds=gnu_stat_mtime_seconds
elif bsd_stat_mtime_seconds . >/dev/null 2>&1; then
    alias stat_mtime_seconds=bsd_stat_mtime_seconds
elif STAT_BIN=gstat gnu_stat_mtime_seconds . >/dev/null 2>&1; then
    export STAT_BIN=gstat
    alias stat_mtime_seconds=gnu_stat_mtime_seconds
else
    alias stat_mtime_seconds=no_good_stat_mtime_seconds
fi
