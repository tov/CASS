# TODO

get_points_helper () {
    case "$1" in
        +*)
            points=${1#+}
            false
            ;;
        *)
            points=${points:-1}
            true
            ;;
    esac
}

alias local_points='local old_points; old_points=${points-}; local points; points=$old_points'
alias get_points='get_points_helper "$@" || shift'
alias local_get_points='local_points; get_points'

add_to () {
    local var
    local value
    var=$1; shift
    value=${!var}
    eval "$var=$(echo "${value:-0} + ( $* )" | bc -l)"
}

score_frac () {
    if [ -n "$DIE_ON_FAILED_TEST" ] && [ "$1" = 0 ] && [ "$2" != 0 ]; then
        echo >&2 "DYING ON FAILED TEST"
        actual=-$possible
        exit 13
    fi

    add_to actual $1
    add_to possible $2
}

score_if () {
    if "$@"; then
        html_test_passed $points
        add_to passed 1
        score_frac $points $points
    else
        html_test_failed $points
        add_to failed 1
        score_frac 0 $points
    fi
}

score_unit_test () {
    local file
    local failures
    local successes
    local total

    file="$2.out"

    score_line=$(sed <"$file" '
        s/Success: \([0-9]\{1,\}\) tests passed.*/0:\1/
        tfound

        s/FAILURE: \([0-9]\{1,\}\) out of \([0-9]\{1,\}\) tests failed.*/\1:\2/
        tfound

        d

        :found
            q
    ')

    # Count the # of tests from the designated file instead of
    # from std output total=$(echo "$score_line" | sed 's/.*://')
    total=$(grep "^TEST(" "$1" | wc -l)

    if [ -z "$score_line" ]; then
        echo "*** Tests for $2 did not complete successfully ***"
        successes=0
    else
        failures=$(echo "$score_line" | sed 's/:.*//')
        add_to failed $failures
        add_to passed $total - $failures
    fi

    score_frac $successes $total
}

reset_points () {
    passed=0
    failed=0
    actual=0
    possible=0
}

# ready to grade:
reset_points

