# Library for grading based on running programs and matching output

COURSE_GRADE_TIMEOUT=15
export COURSE_GRADE_TIMEOUT

find_team_repo () {
    echo "$COURSE_VAR/grading/$2-$1"
}

find_existing_file () {
    local file

    for file; do
        if [ -f "$file" ]; then
            echo $file
            return
        fi
    done
}

find_grading_script () {
    find_existing_file \
        "$COURSE_LIB/grading/$1/grade_this" \
        "$COURSE_LIB/grading/grade_this_$1"
}

find_preparation_script () {
    find_existing_file \
        "$COURSE_LIB/grading/$1/prepare_this" \
        "$COURSE_LIB/grading/prepare_this_$1"
}

sgrep () {
    egrep "$@" >/dev/null 2>&1
}

score () {
    test -n "$actual"   || actual=0
    test -n "$possible" || possible=0

    actual=$(expr $actual + $1)
    possible=$(expr $possible + $2)
}

score_if () {
    test -n "$passed"   || passed=0
    test -n "$failed"   || failed=0

    local denom
    denom="$1"; shift
    if "$@"; then
        echo "+++ PASSED ($denom / $denom points)"
        passed=$(expr $passed + 1)
        score $denom $denom
    else
        echo "--- FAILED (0 / $denom points)"
        failed=$(expr $failed + 1)
        score 0 $denom
    fi
}

score_unit_test () {
    local file
    local failures
    local successes
    local total

    file="$1.out"

    score_line=$(sed <"$file" '
        s/Success: \([0-9]\{1,\}\) tests passed.*/0:\1/
        tfound

        s/FAILURE: \([0-9]\{1,\}\) out of \([0-9]\{1,\}\) tests failed.*/\1:\2/
        tfound

        d

        :found
            q
    ')

    failed=$(echo "$score_line" | sed 's/:.*//')
    total=$(echo "$score_line" | sed 's/.*://')
    passed="$(expr $total - $failed)"

    score $passed $total
}

expect () {
    local file
    local points
    local pattern

    file="$1.out"; shift
    points=1

    while [ -n "$1" ]; do
        case "$1" in
            +*)
                points=$(printf "%s" "$1" | sed 's/^[+]//'); shift
                ;;
        esac
        pattern="$1"; shift

        printf "Looking for pattern ‘%s’ in file ‘%s’\n" "$pattern" "$file"

        score_if $points sgrep -i "$pattern" "$file"
    done
}

headingf () {
    local char; char="$1"; shift
    local fmt;  fmt="$1";  shift
    echo
    printf "$fmt\n" "$@" | sed "s/./$char/g"
    printf "$fmt\n" "$@"
    printf "$fmt\n" "$@" | sed "s/./$char/g"
}

prepare_test () {
    local progname
    local tag
    local out
    eval "$(getargs progname tag ...)"

    out="$progname-$tag.out"

    headingf - "Test %s-%s" "$progname" "$tag"

    echo "Preparing input for $progname:"
    "$@" | sed 's/^/> /'
    echo

    printf "Running (output to ‘%s’)... " "$out"

    "$COURSE_BIN/make_jail.sh" jail
    cp $progname jail
    "$@" | sudo "$COURSE_BIN/timeout.sh" $COURSE_GRADE_TIMEOUT \
            chroot jail /$progname >"$out" 2>&1
    rm -Rf jail

    printf "done.\n"

    sed 's/^/< /' "$out"
    echo
}

print_points_summary () {
    headingf \* "*** SUMMARY ***"
    printf "Tests passed:      %3d\n" $passed
    printf "Tests failed:      %3d\n" $failed
    printf "Points earned:     %3d\n" $actual
    printf "Points possible:   %3d\n" $possible
    printf "Correctness score: %5.1f%%\n" \
            $(echo "100 * $actual / $possible" | bc -l)

    echo
    echo "$actual / $possible" | bc -l
}
