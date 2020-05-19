#!/bin/sh

. "$(dirname "$0")/.CASS"
course_use find grade

# Grant extensions on homeworks
#
# -N            dry run -- don't actually extend
# -R            don't resolve NetIDs
# -U            don't upload log
# -q            quiet

select_netids () {
    local netid
    if [ -n "$netids" ]; then
        for netid in $netids; do
            resolve_student $flag_R "$netid"
        done
    else
        all_netids | while read netid; do
            test -L "$(find_team_repo $hw $netid)" ||
                echo "$netid"
        done
    fi
}

eprintf () {
    printf "$@" >&2
    printf "$@"
}

extend_all () {
    local netid
    local repo
    local log

    while read netid; do
        repo=$(find_team_repo $hw $netid)
        mkdir -p "$repo"
        log=$repo/extension.log
        extend_one 2>&1 1>"$log"

        if [ -z "$flag_U" ]; then
            $_N gsc -u $netid cp "$log" hw$hw: || true
        fi
    done
}

extend_one () {
    echo "Hello, I am ${0##*/}, and the time is $(date)."
    echo

    if unit_score=$(get_hw_score $hw $netid); then
        score=$(bc_expr "100 * $unit_score")
    else
        score=-
    fi

    if goal=$(get_hw_goal $hw $netid); then
        if [ -n "$goal" ]; then
            printf 'Test score goal set to %g%%.\n' "$goal"
        else
            printf 'No goal.txt found.\n'
        fi
    else
        eprintf 'hw%02d/%s: Error: Couldn’t parse goal.txt\n' $hw $netid
        eprintf '  expected contents: a number\n'
        eprintf '  actual contents:   ‘%s’\n\n' "$goal"
        goal=
    fi

    if [ -z "$goal" ]; then
        goal=100
        printf 'Test score goal defaulted to %g%%.\n\n' "$goal"
    fi

    if [ "$score" = - ]; then
        score=0
        printf 'Not yet tested.\n\n'
    else
        printf 'Actual test score is %g%%.\n\n' "$score"
    fi

    if bc_cond "$score < $goal"; then
        eprintf 'hw%02d/%s: Granting extension.\n' $hw $netid
        $_N "$COURSE_BIN"/extend.sh -f $hw $netid \
            tomorrow $(date +%H:59)
    else
        eprintf 'hw%02d/%s: No extension needed.\n' $hw $netid
    fi
    echo
}

eval "$(getargs -NRUq hw netids...)"

if [ -n "$flag_q" ]; then
    exec 1>/dev/null
fi

_N=
if [ -n "$flag_N" ]; then
    _N='echo (dry run)'
fi

select_netids | extend_all

