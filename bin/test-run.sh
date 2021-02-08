#!/bin/sh

exec 9<"$0"
if ! flock -en 9; then
    printf '%s: could not acquire lock [%s]\n\n' "$0" "$(date)"
    ps uxww
    exit 2
fi >&2

set -eu
. "$(dirname "$0")/.CASS"
eval "$(getargs log_level=-)"

export LATENCY='=not scheduled'
export PATH=$HOME/.cargo/bin:/usr/local/bin:/usr/bin:/bin

alias now="date +'[%b %d %H:%M:%S]'"

child_pids=
finish_run () {
    set +e
    ( printf '\n' >&2 ) && exec >&2

    echo "Okay, $$ cleaning up:"

    for child in $child_pids; do
        echo " - quitting $child..."
        kill -QUIT "$child"
    done

    echo " - sleeping 5 seconds..."
    sleep 5

    for child in $child_pids; do
        echo " - killing $child..."
        kill -KILL "$child"
    done

    echo "Okay, $$ exiting"
    exit
}
trap finish_run INT QUIT

one_attempt () {
    info "Trying: $*"
    "$@" || {
        exit_code=$?
        warn "Failed ($exit_code): $*"
        return $exit_code
    }
}

retry () {
    cmd=$1; shift
    now
    one_attempt "$cmd" -q "$@" || {
        exit_code=$?
        ROBUSTNESS=$(expr 2 \* ${ROBUSTNESS:-5})
        warn "Doubling ROBUSTNESS to $ROBUSTNESS"
        now
        one_attempt "$cmd" "$@"
    }
    now
}

one_run () {
    local flags
    flags=
    while [ $# -gt 0 ]; do
        case "$1" in
            -*)
                flags="$flags $1"
                shift
                ;;
            *)
                break
                ;;
        esac
    done

    local hw; hw=$1; shift
    export ROBUSTNESS; ROBUSTNESS=15

    (
    open_log hw$hw
    retry "$COURSE_BIN"/grade_all_projects $flags $hw "$@"
    ) &

    advance_log_level
}

do_flock () {
    TEST_RUN_LOCKED=1 \
        flock --conflict-exit-code 22 --close --nonblock --verbose \
        "$log_dir" \
        env TEST_RUN_LOCKED=1 \
        "$@"
}

dbug () {
    echo "($$) $*" >&3
}

info () {
    echo "$(now) $*"
}

warn () {
    info "*** $* ***" >&2
}

open_log () {
    local log="$log_dir"/$start_time-$1.log

    case "$log_level" in
        -3*) exec 1>&7    2>&7  3>&8       ;;
        -2*) exec 1>&7    2>&8  3>/dev/null;;
        -1*) exec 1>$log  2>&7  3>/dev/null;;
        -0*) exec 1>$log  2>&1  3>&1       ;;
        *)   exec 1>$log  2>&1  3>/dev/null;;
    esac
}

advance_log_level () {
    case "$log_level" in
        -?*) log_level=-${log_level#-?} ;;
    esac
}

main () {
    start_time=$(date +%Y%m%d-%H%M)

    log_dir="$HOME"/test-logs/$course_id
    mkdir -p "$log_dir"

    exec 7>&1
    exec 8>&2

    . "$COURSE_VAR"/current-test-run

    wait
}

######
main #
######
