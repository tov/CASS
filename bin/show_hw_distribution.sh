#!/bin/sh

. "$(dirname "$0")/.CASS"
course_use find

# Shows the automated-test grade distribution for hw$hw.
#
#  -P           show raw points, not percentages
#  -r           reverse order (highest scores first)

process_arguments () {
    eval "$(getargs -Pr hw)"

    if [ -z "$flag_P" ]; then
        format='%5.1f%%\n'
        points=100
    else
        format='%3.0f\n'
        points=$(possible_points)
    fi
}

find_logs () (
    all_netids | while read netid; do
        repo=$(find_team_repo $hw $netid)
        log=$repo/tests.log
        if [ -d "$repo" ] && [ -f "$log" ]; then
            echo "$log"
        fi
    done
)

possible_points () {
    sed -E '
        /^Points possible: *([0-9]*) *$/!d
        s//\1/
    ' "$(find_team_repo $hw starter)/tests.log" | head -1
}

read_scores () {
    while read test_log; do
        tail -1 "$test_log"
    done
}

format_scores () {
    while read score; do
        if [ "$score" = - ]; then
            printf '%s\n' ---
        else
            printf "$format" "$(bc_expr "$points * $score")"
        fi
    done
}

build_histogram () {
    sort $flag_r -n | uniq -c
}

process_arguments "$@"

find_logs       |
read_scores     |
format_scores   |
build_histogram

