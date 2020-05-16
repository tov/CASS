#!/bin/sh

. "$(dirname "$0")/.CASS"
course_use find grade

# Grant extensions on homeworks
#
# -N            dry run -- don't actually extend
# -R            don't resolve NetIDs
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

extend_all () {
    local netid
    local log

    while read netid; do
        log=$(find_team_repo $hw $netid)/extension.log
        extend_one 2>&1 | tee $log
        $_N gsc -u $netid cp $log hw$hw:
    done
}

extend_one () {
    unit_score=$(get_hw_score $hw $netid || echo 0)
    score=$(bc_expr "100 * $unit_score")

    if goal=$(get_hw_goal $hw $netid); then
        if [ -n "$goal" ]; then
            printf 'Test score goal set to %g%%.\n' "$goal"
        else
            printf 'No goal.txt found.\n'
        fi
    else
        printf>&2 'Error: Couldn’t parse goal.txt\n'
        printf>&2 '  expected contents: a number\n'
        printf>&2 '  actual contents:   ‘%s’\n' "$goal"
        goal=
    fi

    if [ -z "$goal" ]; then
        goal=100
        printf 'Test score goal defaulted to %g%%.\n' "$goal"
    fi

    printf 'Actual test score is %g%%.\n' "$score"

    if bc_cond "$score < $goal"; then
        echo 'Granting extension.'
        $_N "$COURSE_BIN"/extend.sh -f $hw $netid tomorrow midnight
    else
        echo 'No extension needed.'
    fi

}

eval "$(getargs -NRq hw netids...)"

if [ -n "$flag_q" ]; then
    exec 1>/dev/null
fi

_N=
if [ -n "$flag_N" ]; then
    _N='echo (dry run)'
fi

select_netids | extend_all

