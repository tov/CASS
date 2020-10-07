#!/bin/sh

. "$(dirname "$0")/.CASS"
course_use find gsc grade student

# Shows the automated-test results for hw$hw.
#
#  -P           show raw points instead of percentages
#  -n           show full names
#  -d           show distribution (implies -s)
#  -s           sorted by score
#  -r           sorted by score, descending
#  -2           don't dedup partners

process_arguments () {
    eval "$(getargs -Pndsr2 hw netids...)"

    if [ -n "$flag_d" -a -n "$netids" ]; then
        cass_error 1 "cannot combine -d flag with NetID(s)"
    fi

    if [ -z "$flag_P" ]; then
        format='%5.1f%%'
        format_len=6
        points=100
    else
        format='%3.0f'
        format_len=3
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
        printf '%-10s' "$netid"
    fi

    if [ "$score" = - ]; then
        printf "  %-${format_len}s  " ---
    else
        printf "  $format  " "$(bc_expr "$points * $score")"
    fi

    if [ -z "$flag_d" -a -n "$flag_n" ]; then
        team_info $netid
    fi

    echo
}

team_info () {
    format_list 'full_name -' 'printf ,\x20' $(gsc_partners $hw $1)
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

        score=$(get_hw_score $hw $netid) ||
            score=-
        print_score "$netid" "$score"
    done
)

possible_points () {
    local log; log=$(find_team_repo $hw starter)/tests.log
    eval "$(elaborate_test_log + "$log")"
    echo $POINTS_POSSIBLE
}

sort_scores () {
    if [ -z "$flag_r$sort_opts" ]; then
        cat
    else
        sort $flag_r $sort_opts
    fi
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

