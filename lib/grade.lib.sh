# Library for grading based on running programs and matching output

COURSE_GRADE_TIMEOUT=5
export COURSE_GRADE_TIMEOUT

COURSE_MAX_OUTPUT=50000
export COURSE_MAX_OUTPUT

tab_char=$(printf '\t')
del_char=$(printf '\177')
lf_char='
'

bc_expr () {
    echo "$*" | bc -l
}

add_to () {
    local var
    local value
    var="$1"; shift
    value=${!var}
    test -n "$value" || value=0
    value=$(bc_expr "$value + ( $* )")
    eval "$var=$value"
}

line_count () {
    wc -l < "$1" | tr -d ' '
}

find_team_repo () {
    printf "%s/grading/%s-hw%02d" "$COURSE_VAR" "$2" "$1"
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

docker_start () {
    local kind
    local name
    local hash
    eval "$(getargs kind name)"

    case "$kind" in
        build)
            hash=$(
                docker run \
                    --name "$name" \
                    --rm --read-only --init --detach \
                    --tmpfs /tmp \
                    --volume "$(pwd):/hw:ro" \
                    --volume "$(pwd)/build:/hw/build:rw" \
                    --workdir /hw \
                    build \
                    sh -c 'sleep 600'
            ) || return 1
            trap "docker kill $hash 1>/dev/null" EXIT
            CURRENT_BUILD_CONTAINER=$hash
            export CURRENT_BUILD_CONTAINER
            ;;
        test)
            hash=$(
                docker run \
                    --name "$name" \
                    --rm --read-only --init --detach \
                    --tmpfs /tmp \
                    --volume "$(pwd):/hw:ro" \
                    --workdir /hw/build \
                    test \
                    sh -c 'sleep 300'
            ) || return 1
            trap "docker kill $hash 1>/dev/null" EXIT
            CURRENT_TEST_CONTAINER=$hash
            export CURRENT_TEST_CONTAINER
            ;;
        *)
            echo >&2 "docker_start: unknown kind: $kind"
            return 1
            ;;
    esac
}

get_current_container_var () {
    local kind
    eval "$(getargs kind)"
    case "$kind" in
        build)
            echo CURRENT_BUILD_CONTAINER
            ;;
        test)
            echo CURRENT_TEST_CONTAINER
            ;;
        *)
            echo >&2 "get_current_container_var: unknown kind: $kind"
            return 1
            ;;
    esac
}

get_current_container () {
    local kind
    local hash
    eval "$(getargs kind)"

    varname="$(get_current_container_var "$kind")"
    eval "hash=\$$varname"

    if [ -n "$hash" ]; then
        echo $hash
    else
        echo >&2 "get_current_container: $varname not set"
        return 1
    fi
}

docker_build () {
    local hash
    hash=$(get_current_container build) || return 1
    docker exec $hash "$@"
}

docker_test () {
    local hash
    hash=$(get_current_container test) || return 1
    gtimeout $COURSE_GRADE_TIMEOUT \
        docker exec --interactive $hash "$@"
}

docker_execute () {
    local command
    local out
    local progname
    local result

    eval "$(getargs command out ...)"

    case "$command" in
        =*)
            command="$(strip_prefix = "$command")"
            ;;
        *)
            command="./$command"
            ;;
    esac

    set -o pipefail
    {
        (
        "$@" |
            docker_test $command 2>&3 |
            sed 's/^/< /'

        result=$?
        echo '#COMPLETE'
        exit $result

        ) 3>&1 1>&2 | sed 's/^/! /'
    } 2>&1 | head -c $COURSE_MAX_OUTPUT > "$out"

    result=$?

    if [ $result = 124 ]; then
        echo '#TIMEOUT' >> "$out"
    fi

    return $result
}

score () {
    add_to actual $1
    add_to possible $2
}

score_if () {
    local denom
    denom="$1"; shift
    if "$@"; then
        echo "+++ PASSED ($denom / $denom points)"
        add_to passed 1
        score $denom $denom
    else
        echo "--- FAILED (0 / $denom points)"
        add_to failed 1
        score 0 $denom
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

    score $successes $total
}

expect_exit () {
    local points
    local expected_code
    local actual_code
    local op

    points=1
    eval "$(update_points "$1")"
    eval "$(getargs -n expected_code actual_code)"

    if [ -n "$flag_n" ]; then
        op='!='
    else
        op='='
    fi

    echo "Expecting exit code $op $expected_code, got $actual_code"
    score_if $points [ "$actual_code" $op "$expected_code" ]
}

strip_prefix () {
    local prefix
    local param

    prefix="$1"; shift
    param="$1"; shift

    case "$param" in
        $prefix*)
            prefix=$(printf '%s' "$prefix" | sed 's/././g')
            printf '%s' "$param" | sed "1s/^$prefix//"
            true
            ;;
        *)
            false
            ;;
    esac
}

update_points () {
    local points

    if points="$(strip_prefix '+' "$1")"; then
        echo "points=$points; shift; true"
    else
        echo "false"
    fi
}

expect_lines () {
    local points
    local correct_output
    local expected_lines
    local actual_lines
    local count_noun

    points=1
    eval "$(update_points "$1")"
    eval "$(getargs correct_output)"

    actual_lines=$(line_count "$last_stdout")
    expected_lines=$(line_count "$correct_output")

    case "$expected_lines" in
        0)
            count_noun='no lines'
            ;;
        1)
            count_noun='one line'
            ;;
        *)
            count_noun="$expected_lines lines"
            ;;
    esac

    echo "Expecting $count_noun of output, got $actual_lines"
    score_if $points [ "$actual_lines" = "$expected_lines" ]
}

expect () {
    local file
    local points
    local pattern
    local line
    local pattern1
    local line1
    local which
    local count

    file="$last_stdout"
    which=stdout
    points=1

    while [ -n "$1" ]; do
        if eval "$(update_points "$1")"; then
            true
        elif [ "$1" = '!' ]; then
            shift
            file="$last_stderr"
            which=stderr
        elif line="$(strip_prefix '@' "$1")"; then
            shift
            pattern="$1"; shift
            sed "$line!d" "$file" > "$file-$line"
            printf "Expecting $which L%d to match pattern ‘%s’\n" \
                "$line" "$pattern"
            score_if $points sgrep -i -- "^ *$pattern *\$" "$file-$line"
        elif pattern="$(strip_prefix '==' "$1")"; then
            shift
            line=$(cat "$file")
            count=0
            while [ -n "$pattern" ]; do
                count=$(expr $count + 1)
                pattern1=$(printf '%s' "$pattern" | sed '1!d' | tr -d '\n')
                line1=$(printf '%s' "$line" | sed '1!d' | tr -d '\n')
                pattern=$(printf '%s' "$pattern" | sed '1d')
                line=$(printf '%s' "$line" | sed '1d')
                test "$pattern1" = _ && continue
                printf "Expecting $which L%d to be exactly ‘%s’\n" \
                    "$count" "$(printf '%s' "$pattern1" | visify)"
                score_if $points [ "$pattern1" = "$line1" ]
            done

            if [ -n "$line" ]; then
                printf "??? Extra output unexpected after L%d\n" $count
            fi
        elif pattern="$(strip_prefix '=' "$1")"; then
            shift
            line=$(cat "$file")
            printf "Expecting $which to be exactly ‘%s’\n" \
                "$(printf '%s' "$pattern" | visify)"
            score_if $points [ "$pattern" = "$line" ]
        else
            pattern="$1"; shift
            printf "Expecting $which to contain pattern ‘%s’\n" \
                    "$pattern"
            score_if $points sgrep -i -- "$pattern" "$file"
        fi
    done
}

run_all_tests () {
    local points
    local infile
    local stem
    local program

    points=1

    while [ -n "$1" ]; do
        if eval "$(update_points "$1")"; then
            shift
            continue
        fi

        infile="$1"; shift
        stem=$(echo "$infile" | sed 's/\.in$//')
        command=$(basename "$stem" | sed 's/-[[:digit:]]*$//;s/@/ /g')

        prepare_test "$command" cat "$infile"
        eval "$(awk '{print "expect +'$points' @" NR " \"" $0 "\""}' \
                "$stem.out")"
        expect_lines +$points "$stem.out"
    done
}

visify () {
    sed -e '
        s/\\/\\\\/g;
        s/'"$tab_char"'/\\t/g;
        s/'"$del_char"'/\\177/g;
        s/ $/\\040/;
    '
}

current_tag=0


prepare_test () {
    local command
    local casename
    local tag
    local out
    local stdout
    local stderr
    eval "$(getargs command ...)"

    tag="$current_tag"
    current_tag=$(expr "$tag" + 1)
    casename="$(echo "$command" | sed 's%[/ ]%@%g')"
    out="logs/$casename-$tag.out"
    stdout="logs/$casename-$tag.stdout"
    stderr="logs/$casename-$tag.stderr"

    mkdir -p logs

    headingf - "Test case %s: %s" "$tag" "$command"

    echo "Preparing input:"
    "$@" | sed 's/^/> /' | visify
    echo

    printf "Running... "

    docker_execute "$command" "$out" "$@"
    result=$?

    printf "done. Output was:\n"


    grep -v '^#' "$out" | visify
    echo

    sed '/^< /!d;s/^< //' "$out" > "$stdout"
    sed '/^! /!d;s/^! //' "$out" > "$stderr"

    if sgrep '^#TIMEOUT$' "$out"; then
        headingf -s ! 'Timeout Error'
        echo Your program was still running after $COURSE_GRADE_TIMEOUT s,
        echo so I killed it.
        echo
        echo You probably have an infinite loop.
        echo
    elif ! sgrep '^#COMPLETE$' "$out"; then
        headingf -s ! 'Excessive Output Error'
        echo
        echo Your program produced more than $COURSE_MAX_OUTPUT bytes
        echo of output, so I killed it.
        echo
        echo You probably have an infinite loop.
        echo
    elif [ "$result" != 0 ]; then
        echo "Exit code: $result"
    fi

    last_stdout="$stdout"
    last_stderr="$stderr"
    return $result
}

assert_absence () {
    local funname
    local filename
    eval "$(getargs funname filename)"
    headingf - "Checking for ‘%s’ in %s (where it shouldn’t be)" \
        "$funname" $(basename "$filename")
    if ! egrep -nC2 "\\<$funname\\>" "$filename" &&
       test -f "$filename"
    then
        score_if 1 true
    else
        score_if 1 false
    fi
}

reset_points () {
    passed=0
    failed=0
    actual=0
    possible=0
}

# ready to grade:
reset_points

print_points_summary () {
    headingf -s \* SUMMARY
    printf "Checks passed:     %3d\n" $passed
    printf "Checks failed:     %3d\n" $failed
    printf "Points earned:     %3d\n" $actual
    printf "Points possible:   %3d\n" $possible
    printf "Correctness score: %5.1f%%\n" \
            $(bc_expr "100 * $actual / $possible")

    echo
    bc_expr "$actual / $possible"
}
