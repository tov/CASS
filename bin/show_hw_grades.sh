#!/bin/sh

. "$(dirname "$0")/.CASS"
course_use find grade

# Shows the automated-test results for hw$hw.
#
#  -P           show raw points instead of percentages
#  -d           show distribution (implies -s)
#  -s           sorted by score
#  -r           sorted by score, descending
#  -2           don't dedup partners

process_arguments () {
    eval "$(getargs -Pdsr2 hw netids...)"

    if [ -n "$flag_d" -a -n "$netids" ]; then
        cass_error 1 "cannot combine -d flag with NetID(s)"
    fi

    if [ -z "$flag_P" ]; then
        format='%5.1f%%'
        points=100
    else
        format='%3.0f'
        points=$(possible_points)
    fi

    if [ -n "$flag_d" ]; then
        sort_opts=-nk1
    elif [ -n "$flag_s$flag_r" ]; then
        sort_opts=-nk2
    else
        sort_opts=
    fi
}

print_score () {
    local netid; netid=$1
    local score; score=$2

    if [ -z "$score" ]; then
        echo "*** missing score: $netid" >&2
        return 0
    fi

    if [ -z "$flag_d" ]; then
        printf '%-15s ' "$netid"
    fi

    if [ "$score" = - ]; then
        printf '%s\n' ---
    else
        printf "$format\n" "$(bc_expr "$points * $score")"
    fi
}

select_netids () {
    if [ -n "$netids" ]; then
        local netid
        for netid in $netids; do
            find_student -q1 "$netid"
        done
    else
        all_netids
    fi
}

read_scores () (
    while read netid; do
        if [ -z "$flag_2" -a -L "$(find_team_repo $hw $netid)" ]; then
            continue
        fi

        if score=$(get_hw_score $hw $netid); then
            print_score "$netid" "$score"
        fi
    done
)

possible_points () {
    sed -E '
        /^Points possible: *([0-9]*) *$/!d
        s//\1/
        q
    ' "$(find_team_repo $hw starter)/tests.log"
}


sort_scores () {
    sort $flag_r $sort_opts
}

build_histogram () {
    if [ -n "$flag_d" ]; then
        uniq -c
    else
        cat
    fi
}

process_arguments "$@"

select_netids   |
read_scores     |
sort_scores     |
build_histogram

