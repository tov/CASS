#!/bin/sh

# Shows the automated-test results for hw$hw.

. "$(dirname "$0")/.CASS"
course_use find gsc grade student

usage () {
    sed -E 's/^ *(,|$)//' <<····EOF
        Usage: $0 [OPTION...] HW [COMP VALUE] NETID...

        OPTIONS:
       ,  -P    show raw points instead of percentages
       ,  -a    show assignment number
       ,  -d    show distribution (implies -s)
       ,  -n    show full names
       ,  -r    sorted by score, descending
       ,  -s    sorted by score
       ,  -2    don't dedup partners
       ,  -h    print this help message

        HW examples:
       ,  2     HW 2 only
       ,  25    HWs 2 and 5
       ,  2-5   HWs 2, 3, 4, and 5
       ,  2-57  HWs 2, 3, 4, 5, and 7

        COMP is one of == != < <= > >=
····EOF
}

process_arguments () {
    eval "$(getargs -Pandsr2h hw_set ...)"

    if [ -n "$flag_h" ]; then
        usage
        exit
    fi

    if [ -n "$flag_d" -a -n "$netids" ]; then
        cass_error 1 "cannot combine -d flag with NetID(s)"
    fi

    hw_set=$(expand_hw_set "$hw_set")
    case $hw_set in
        (*\ *) flag_a=-a ;;
    esac

    local exp; exp="$(expand_comparison "${1-}")"
    case $exp in
        ('=='|'!='|'<'|'<='|'>'|'>=')
            define_include_score "$exp ${2?:a number following $1}"
            shift; shift
            ;;

        ('=='*|'!='*|'<'*|'<='*|'>'*|'>='*)
            define_include_score "$exp"
            shift
            ;;

        (*)
            define_include_score '|| 1'
            ;;
    esac

    netids="$*"

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

expand_comparison () {
    printf '%s\n' "$1" | sed '
        s/^≤/<=/
        s/^≥/>=/
        s/^≥/!=/
        s/^=[^=]/=&/
    '
}

expand_hw_set () {
    local n
    local m
    local rest; rest="${1-}."

    while [ "$rest" != . ]; do
        n=$(expr "$rest" : '\(.\)')

        case $rest in
            ([0-9]-[0-9]*)
                m=$(expr "$rest" : '..\(.\)')
                while [ $n -le $m ]; do
                    echo $n
                    : $(( ++n ))
                done
                rest="$(expr "$rest" : '...\(.*\)')"
                ;;

            ([0-9]*)
                echo $n
                rest="$(expr "$rest" : '.\(.*\)')"
                ;;

            (\ *)
                rest="$(expr "$rest" : '.\(.*\)')"
                ;;

            (*)
                cass_error 10 "bad HW spec: $1"
                ;;
        esac
    done | sort -n | uniq | tr '\n' ' ' | sed 's/ $//'
}

define_include_score () {
    eval "
        include_score () {
            test 1 = \$(( \$1 $1 ))
        }
    "
}

print_score () {
    local netid; netid=$1
    local score; score=$2

    if [ -z "$score" ]; then
        echo "*** missing score: $netid" >&2
        return 0
    fi

    local pct
    pct=$(bc_expr "100 * 0${score%-}" | sed 's/[.].*//')
    include_score $pct || return 0

    if [ -n "$flag_a" ]; then
        printf 'hw%02d/' $hw
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
        for hw in $hw_set; do
            if [ -z "$flag_2" -a -L "$(find_team_repo $hw $netid)" ]; then
                continue
            fi

            score=$(get_hw_score $hw $netid) || score=-
            print_score "$netid" "$score"
        done
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

