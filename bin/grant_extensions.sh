#!/bin/sh

. "$(dirname "$0")/.CASS"
course_use find grade

LANG=en_US.UTF-8
export LANG

# Grant extensions on homeworks
#
# -N            dry run -- don't actually extend
# -R            don't resolve NetIDs
# -U            don't upload log
# -v            verbose GSC
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

_E () {
    "$@" | tee /dev/fd/2
}

extend_all () {
    local netid
    local slug
    local repo
    local log

    while read netid; do
        slug=$(printf hw%02d/%s $hw $netid)
        repo=$(find_team_repo $hw $netid)
        mkdir -p "$repo"
        log=$repo/extension.log

        if [ -f "$log" ]; then
            first_time=false
        else
            first_time=true
        fi

        extend_one 2>&1 >"$log"

        if [ -z "$flag_U" ]; then
            _N gsc $flag_v -u $netid cp "$log" hw$hw: || true
        fi
    done
}

date_fmt='%A, %d %B'
time_fmt='%l:%M %p'
datetime_fmt="$time_fmt on $date_fmt (%Z)"
tomorrow_fmt="$time_fmt %Z tomorrow (%a.)"
gscd_fmt='%Y-%m-%d %H:%M:%S %z'

next_deadline () {
    deadline=$(gdate +'tomorrow %H:59')
    machine_datetime=$(gdate -d "$deadline" +"$gscd_fmt")
    human_datetime=$(gdate -d "$deadline" +"$tomorrow_fmt")
}

pct_score () {
    printf '%.3g%%' "$1"
}

graf () {
    sed 's/^ *//' | fmt -72
    echo
}

extend_one () {
    if unit_score=$(get_hw_score $hw $netid); then
        score=$(bc_expr "100 * $unit_score")
    else
        score=-
    fi

    if $first_time; then
        echo "Hello, I am ${0##*/}, and the time is"
        date +"$datetime_fmt".
    else
        echo "Hello again, I am ${0##*/}, and it’s now"
        date +"$datetime_fmt".
    fi | graf

    if ! goal=$(get_hw_goal $hw $netid); then
        goal=101
        graf <<........GRAF
            I found your goal.txt, but I had some trouble
            understanding it. Here’s the error message:
........GRAF
        _E echo "  $slug: Error: Couldn’t parse goal.txt"
        _E echo "    expected content:  a number between 0 and 100"
        _E echo "    actual content:    ‘${goal}’"
        _E echo
        graf <<........GRAF
            I’ll set your goal to ${goal}% for now to be safe.
            Be sure to put nothing but the number,
            like 75 or 99, in the file.
........GRAF
    elif [ -z "$goal" ]; then
        goal=100
        graf <<........GRAF
            Looks like you haven’t uploaded a goal.txt.
            I’ll set your goal to 100% for now.
            That’s just the default, though, and you may
            set it however you wish.
........GRAF
    else
        graf <<........GRAF
            I found your goal.txt.
            It looks like your goal is $(pct_score $goal).
........GRAF
    fi

    (
    if [ "$score" = - ]; then
        score=0
        echo 'Looks like you don’t have a test score yet.'
    else
        echo "Your test score is $(pct_score $score)."
    fi

    if bc_cond "$score < $goal"; then
        echo>&2 "$slug: Granting extension."
        next_deadline
        echo "You now have an extension until ${human_datetime# }."
        _N gsc $flag_v admin extend hw$hw $netid "$machine_datetime"
    else
        echo>&2 "$slug: No extension needed."
        echo 'No extension needed.'
        if bc_cond "$score >= 100" || bc_cond "$goal >= 80"; then
            echo 'Congrats!'
        fi
    fi
    ) | graf
}

eval "$(getargs -NRUvq hw netids...)"

if [ -n "$flag_q" ]; then
    exec 1>/dev/null
fi

if [ -n "$flag_N" ]; then
    _N () {
        echo '(dry run)' "$*"
    }
else
    _N () {
        "$@" >/dev/null
    }
fi

select_netids | extend_all

