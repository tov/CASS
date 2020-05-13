#!/bin/sh

. "$(dirname "$0")/.CASS"
course_use find

# Shows the automated-test grade distribution for hw$hw.
#
#  -P           show raw points instead of percentages
#  -d           show distribution (implies -s)
#  -s           sorted by score
#  -r           sorted by score, descending
#  -2           don't dedup partners

process_arguments () {
    eval "$(getargs -Pdsr2 hw)"

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

read_scores () (
    all_netids | while read netid; do
        repo=$(find_team_repo $hw $netid)
        log=$repo/tests.log

        if ! [ -f "$log" ] ||
            { [ -z "$flag_2" ] && [ -L "$repo" ]; }
        then
            continue
        fi

        print_score "$netid" "$(tail -1 "$log")"
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

read_scores     |
sort_scores     |
build_histogram

