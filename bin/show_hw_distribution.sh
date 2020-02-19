#!/bin/sh

. "$(dirname "$0")/.CASS"

# Shows the autograder grade distribution for hw$hw.
#
#  -P           don't multiply scores by points possible

process_arguments () {
    eval "$(getargs -P hw)"

    cd "$(printf %s/grading/hw%02d "$COURSE_VAR" "$hw")"

    if [ -n "$flag_P" ]; then
        format='%5.1f%%\n'
        points=100
    else
        format='%3.0f\n'
        points=$(possible_points)
    fi
}

find_logs () (
    for netid; do
        log=$netid/tests.log
        if [ -d "$netid" ] && [ -f "$log" ]; then
            echo "$log"
        fi
    done
)

possible_points () {
    find_logs * |
        while read test_log; do
            cat "$test_log"
        done |
        sed -E '
            /^Points possible: *([0-9]*) *$/!d
            s//\1/
        ' |
        head -1
}

read_scores () {
    while read test_log; do
        tail -1 "$test_log"
    done
}

format_scores () {
    while read score; do
        printf "$format" "$(bc_expr "$points * $score")"
    done
}

build_histogram () {
    sort -n | uniq -c
}

process_arguments "$@"

find_logs *     |
read_scores     |
format_scores   |
build_histogram

