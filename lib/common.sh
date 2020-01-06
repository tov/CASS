# Common definitions for CASS (course admin shell scripts).

set -o pipefail

find_course_root () {
    cd "$(dirname $0)"

    while ! [ -f .root ]; do
        if [ "$(pwd)" = / ]; then
            echo >&2 Could not find course root
            exit 3
        fi
        cd ..
    done

    pwd
}

COURSE_ROOT="$(find_course_root)" || exit 3
COURSE_BIN="$COURSE_ROOT/bin"
COURSE_LIB="$COURSE_ROOT/lib"
COURSE_ETC="$COURSE_ROOT/etc"
COURSE_VAR="$COURSE_ROOT/var"
export COURSE_ROOT COURSE_BIN COURSE_LIB COURSE_ETC COURSE_VAR

COURSE_DB="$COURSE_VAR/db"
COURSE_CACHE="$COURSE_VAR/cache"
export COURSE_DB COURSE_CACHE

. "$COURSE_ETC/config.sh"

course_use () {
    local each
    for each; do
        . "$COURSE_LIB/$each.sh"
    done
}

course_load_env () {
    local var
    local file

    var="$1"
    file="$COURSE_ETC/$2"

    if [ -f "$file" ]; then
        eval "$var=\$(cat \"$file\"); export $var"
    fi
}

course_load_env CANVAS_OAUTH canvas_oauth
course_load_env GITHUB_OAUTH github_oauth
course_load_env CODECOV_TOKEN codecov_token

# Only used by old 230.
locate_grade () {
    local hw="$1"
    local netid="$2"
    echo "$COURSE_DB/grades/$netid/$hw"
}

# Only used by old 230.
locate_grade_dir () {
    local netid="$1"
    echo "$COURSE_DB/grades/$netid"
}

# Only used by 211 and old 230.
find_team_repo () {
    echo "$COURSE_VAR/grading/$2-hw$1"
}

contains_string () {
    local needle="$1"
    local haystack="$2"

    echo "$haystack" | grep ".*$needle.*" >/dev/null 2>&1
}

explode_word () {
    echo "$*" | sed 's/./& /g'
}

remove_leading_hyphen () {
    echo "$*" | sed 's/^-//'
}

getargs () {
    (
    usage='Usage: eval "$(getargs [+] [-OPTS] ARGNAME... [...])"'

    if [ "$1" = '+' ]; then
        shift
        define_var () {
            echo "local $1; $1=$2"
        }
    else
        define_var () {
            echo "$1=$2"
        }
    fi

    case "$1" in
        --help|'')
            echo "$usage"
            return 0
            ;;
        -*)
            flags="$(remove_leading_hyphen $1)"
            shift;
            ;;
    esac

    if [ -n "$flags" ]; then
        for flag in $(explode_word "$flags"); do
            define_var "flag_$flag" ''
        done
        echo 'while [ -n "$1" ]; do'
        echo '  case "$1" in'
        echo '    --) shift; break;;'
        echo '    -)  break;;'
        echo '    -*)'
        echo '      for flag in $(explode_word $(remove_leading_hyphen $1)); do'
        printf '        if contains_string $flag "%s"; then\n' $flags
        echo '          eval "flag_$flag=-$flag"'
        echo '        else'
        printf '          echo>&2 "Usage: $0 -%s ' $flags
        printf '%s"\n' "$*" | tr a-z A-Z
        echo '          exit 2'
        echo '        fi'
        echo '      done'
        echo '      shift;;'
        echo '    *)  break;;'
        echo '  esac'
        echo 'done'
    fi

    for arg; do
        if [ "$arg" = ... ]; then
            etc='-z not-z'
            break
        else
            etc='-n "$*"'
        fi

        printf '%s="$1"; shift\n' $arg
    done

    printf 'if [ %s' "$etc"
    for arg; do
        printf ' -o -z "$%s"' $arg
    done
    printf ' ]; then\n'
    printf '    echo>&2 "Usage: $0 '
    if [ -n "$flags" ]; then
        printf '%s%s ' - "$flags"
    fi
    printf '%s"\n' "$*" | tr a-z A-Z
    printf '    exit 2\nfi\n'

    )
}

headingf () {
    eval "$(getargs + -s char fmt ...)"

    if [ -n "$flag_s" ]; then
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

find_single () {
    eval "$(getargs + description ...)"

    if [ $# != 1 ]; then
        printf "Cannot resolve %s\n" "$description" >&2
        printf "Candidates were: %s\n" "$*" | fmt   >&2
        exit 2
    fi

    printf '%s\n' "$1"
}

find_single_matching () {
    eval "$(getargs + description pattern ...)"

    find_single "$description" $("$@" | egrep -i "$pattern")
}

find_netid () {
    eval "$(getargs + regexp)"

    find_single_matching "student: $regexp" "^$regexp" \
        "$COURSE_BIN/all_students.sh"
}

find_netids_by_info () {
    eval "$(getargs + regexp)"

    egrep -il "$regexp" "$COURSE_DB"/students/*/* |
            sed 's@.*/students/@@;s@/.*@@' |
            sort |
            uniq
}

whitespace_for_find_student=$(printf '\r\n\t ')

# Finds student matching "$regexp"
find_student () {
    eval "$(getargs + -q1 regexp)"

    local netid
    if ! netid=$(find_netid "$regexp" 2>/dev/null); then
        netid=$(find_netids_by_info "$regexp" 2>/dev/null)

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
        fi >&2
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
    find_student -q1 "$@"
}

print_student_info () {
    if [ "$1" = "-n" ]; then
        printf '%-7s ' "$2"
        shift
    fi

    printf '%s %s <%s>\n' \
        "$(cat "$COURSE_DB"/students/$1/first)" \
        "$(cat "$COURSE_DB"/students/$1/last)" \
        "$(cat "$COURSE_DB"/students/$1/email)"
}

# This code may be dead.
resolve_team () {
    eval "$(getargs + hw pattern)"

    find_single_matching "team: $pattern" "\\<$pattern" \
            "$COURSE_BIN/all_teams.sh" $hw
}

search_and_replace () {
    eval "$(getargs + patt repl ...)"

    local file
    for file; do
        ex - "$file" <<........EOF
            g/$patt/s^^$repl^g
            wq
........EOF
    done
}

cache_eval () {
    local file
    file="$COURSE_CACHE/$1"
    shift

    {
        test -f "$file" || "$@" >"$file"
    } &&
    cat "$file"
}

is_cached () {
    test -f "$COURSE_CACHE/$1"
}

show_progress () {
    eval "$(getargs + message ...)"
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
