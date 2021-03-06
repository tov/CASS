# Helpers for finding stuff

HW_BASE=$COURSE_ROOT/dev/hw
REPO_BASE=$COURSE_VAR/grading

format_homework () {
    printf "hw%02d" "$1"
}

find_team_repo () {
    printf '%s/hw%02d/%s' "$REPO_BASE" "$1" "$(netid_dirname "$2")"
}

find_tests_log () {
    printf '%s/tests.log' "$(find_team_repo "$1" "$2")"
}

find_goal_txt () {
    printf '%s/goal.txt' "$(find_team_repo "$1" "$2")"
}

find_homework () {
    printf "%s/%02d" "$HW_BASE" "$1"
}

find_homework_script () {
    printf "%s/tester/%s_this" "$(find_homework "$1")" "$2"
}

netid_dirname () {
    if netid_is_special "$1"; then
        printf .%s "$1"
    else
        printf %s "$1"
    fi
}

netid_is_special () {
    case "$1" in
        starter|solution) true;;
        *) false;;
    esac
}

expand_hw_set () (
    for piece in $(printf %s "$*" | tr , ' '); do
        case $piece in
            (*-*-*)
                cass_error 10 "bad HW spec: $piece"
                ;;

            (*-*)
                n=${piece%-*}
                m=${piece#*-}

                n=${n:-1}
                m=${m:-${HW_COUNT?must be set to use open-ended HW range}}

                while [ $n -le $m ]; do
                    echo $((n++))
                done
                ;;

            (*-*)
                cass_error 10 "bad HW spec: $piece"
                ;;

            ([0-9]*)
                echo $piece
                ;;

            (*)
                cass_error 10 "bad HW spec: $1"
                ;;
        esac
    done | sort -n | uniq | tr '\n' ' ' | sed 's/ $//'
)
