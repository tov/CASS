# Library for grading based on running programs and matching output

: ${COURSE_GRADE_TIMEOUT:=5}
: ${COURSE_MAX_OUTPUT:=10000}
export COURSE_GRADE_TIMEOUT COURSE_MAX_OUTPUT

build_log=build.log
tests_log=tests.hlog

current_tag=0

course_use docker html points
# TODO: remove?
course_use find

trap '! $html_in_test_case || print_points_summary' EXIT

bc_expr () {
    echo "$*" | bc -l
}

run_all_tests () {
    local points; get_points

    local stem
    local program

    local in_arg; in_arg=-
    local out_arg; out_arg=-
    local err_arg; err_arg=-
    local log_arg; log_arg=-
    local msg_arg; msg_arg=-
    local code_arg; code_arg=-

    while [ -n "$1" ]; do
        stem=${1%.in}; shift
        in_arg=-0$stem.in

        if [ -f "$stem.cmd" ]; then
            command=$(cat "$stem.cmd")
        else
            command=$(basename "$stem" |
                sed -E 's/-[[:digit:]]*$//; s/@/ /g')
        fi

        if [ -f "$stem.out" ]; then
            out_arg=-1$stem.out
        fi

        if [ -f "$stem.err" ]; then
            err_arg=-2$stem.err
        fi

        if [ -f "$stem.log" ]; then
            log_arg=-3$stem.log
        fi

        if [ -f "$stem.msg" ]; then
            msg_arg=-m$stem.msg
        fi

        if [ -f "$stem.code" ]; then
            code_arg=-c$(cat "$stem".code)
        fi

        prepare_test "$command" "$in_arg" "$msg_arg" \
            "$code_arg" "$out_arg" "$err_arg" "$log_arg"
    done
}

prepare_test () {
    local points; points=1
    local command; command=$1; shift
    local casename
    local tag
    local message
    local exp_stdin
    local exp_stdout
    local exp_stderr
    local exp_stdlog
    local exp_exitcode
    local act_out
    local act_stdin
    local act_stdout
    local act_stderr
    local act_stdlog
    local act_exitcode

    while [ -n "$1" ]; do
        case "$1" in
            +*)
                points=${1#+}
                shift
                ;;
            -)
                shift
                ;;
            -m)
                message=$2
                shift; shift
                ;;
            -m*)
                message=${1#-m}
                shift
                ;;
            -0)
                exp_stdin=$2
                shift; shift
                ;;
            -0*)
                exp_stdin=${1#-0}
                shift
                ;;
            -1)
                exp_stdout=$points:$2
                shift; shift
                ;;
            -1*)
                exp_stdout=$points:${1#-1}
                shift
                ;;
            -2)
                exp_stderr=$points:$2
                shift; shift
                ;;
            -2*)
                exp_stderr=$points:${1#-2}
                shift
                ;;
            -3)
                exp_stdlog=$points:$2
                shift; shift
                ;;
            -3*)
                exp_stdlog=$points:${1#-3}
                shift
                ;;
            -c)
                exp_exitcode=$points:$2
                shift; shift
                ;;
            -c*)
                exp_exitcode=$points:${1#-c}
                shift
                ;;
            -C)
                exp_exitcode=$points:\!$2
                shift; shift
                ;;
            -C*)
                exp_exitcode=$points:\!${1#-C}
                shift
                ;;
            --)
                shift
                break
                ;;
            *)
                break
                ;;
        esac
    done

    tag=$(( current_tag++ ))
    casename="$(echo "$command" | sed 's%[/ ]%@%g')"
    act_out="logs/$casename-$tag.out"
    act_stdin="logs/$casename-$tag.stdin"
    act_stdout="logs/$casename-$tag.stdout"
    act_stderr="logs/$casename-$tag.stderr"
    act_stdlog="logs/$casename-$tag.stdlog"
    act_exitcode="logs/$casename-$tag.exitcode"

    mkdir -p logs

    html_test_case 'Test case %s: <code class="filename">%s</code>' \
        "$tag" "$command"

    if [ -n "$message" ]; then
        html_p "$(cat "$message")"
    fi

    html_subhead Input:
    if [ -n "$exp_stdin" ]; then
        cat "$exp_stdin"
    fi > "$act_stdin"
    sed 's/^/< /' "$act_stdin" | html_io_lines

    if [ -n "$exp_stdout$exp_stderr" ]; then
        html_subhead "Expected Output:"
        {
            if [ -n "$exp_stderr" ]; then
                sed 's/^/! /' "${exp_stderr#*:}"
            fi
            if [ -n "$exp_stdout" ]; then
                sed 's/^/> /' "${exp_stdout#*:}"
            fi
        } | html_io_lines

        html_subhead "Actual Output:"
    else
        html_subhead "Output:"
    fi

    docker_execute "$command" "$act_exitcode" \
        <"$act_stdin" 2>"$act_stdlog" \
        | tee "$act_out" | html_io_lines

    if [ -n "$exp_stdlog" ]; then
        html_subhead "Expected Test Log:"
        sed 's/^/: /' "${exp_stdlog#*:}" | html_io_lines
        html_subhead "Actual Test Log:"
        sed 's/^/: /' "$act_stdlog" | html_io_lines
    fi

    sed '/^> /!d;s/^..//' "$act_out" >|"$act_stdout"
    sed '/^! /!d;s/^..//' "$act_out" >|"$act_stderr"
    last_exitcode=$(cat "$act_exitcode")

    points=${exp_exitcode%%:*}
    case "$exp_exitcode" in
        *:\!*)
            exp_exitcode=${exp_exitcode#*:\!}
            html_expect "exit code ≠ $exp_exitcode, got $last_exitcode"
            score_if [ $exp_exitcode != "$last_exitcode" ]
            ;;
        *:*)
            exp_exitcode=${exp_exitcode#*:}
            html_expect "exit code $exp_exitcode, got $last_exitcode"
            score_if [ $exp_exitcode = "$last_exitcode" ]
            ;;
        *)
            check_last_exitcode
            ;;
    esac

    if [ -n "$exp_stdlog" ]; then
        points=${exp_stdlog%%:*}
        exp_stdlog=${exp_stdlog#*:}
        html_check "expected grader log"
        score_if cmp -s "$exp_stdlog" "$act_stdlog"
    fi

    if [ -n "$exp_stdout" ]; then
        points=${exp_stdout%%:*}
        exp_stdout=${exp_stdout#*:}
        html_check "expected standard output"
        score_if cmp -s "$exp_stdout" "$act_stdout"
    fi

    if [ -n "$exp_stderr" ]; then
        points=${exp_stderr%%:*}
        exp_stderr=${exp_stderr#*:}
        html_check "expected standard error"
        score_if cmp -s "$exp_stderr" "$act_stderr"
    fi

    last_stdout=$act_stdout
    last_stderr=$act_stderr
    last_stdlog=$act_stdlog
}

check_last_exitcode () {
    case "$last_exitcode" in
        '')
            echo>&2 THIS SHOULD NOT HAPPEN
            exit 10
            ;;

        0)
            ;;

        124)
            html_subhead 'Timeout Error'
            fmt <<-············EOF
		Your code was still running after
		$COURSE_GRADE_TIMEOUT s, so I killed it.

		You likely have an infinite loop.
············EOF
            ;;

        125)
            html_subhead 'Excessive Output Error'
            fmt <<-············EOF
		Your code produced more than $COURSE_MAX_OUTPUT bytes
		of output, so I killed it.

		You likely have an infinite loop.
············EOF
            ;;

        *)
            html_subhead 'Exit code: %s' "$last_exitcode"
            ;;
    esac
}

assert_absence () {
    local points; get_points
    local funname; funname=$1; shift
    local filename; filename=$1; shift

    local hfunname="<var>$funname</var>"
    local hfilename="<code class=\"filename\">$filename</code>"
    local hbfilename="<code class=\"filename\">$(basename "$filename")</code>"
    local pat; pat="(^|[^[:alnum:]])($funname *[(])"

    html_test_case "Checking for %s in %s" "$hfunname" "$hbfilename"

    html_p "There should not be any calls to function $hfunname
    in file $hfilename, because $hfilename should not contain code that
    calls $hfunname directly."

    if egrep -sq "$pat" "$filename"; then
        egrep -nC2 "$pat" "$filename" 2>&1 | html_grep_output || true
        score_if false
    else
        score_if true
    fi
}

points_summary_tr () {
    printf "<tr><th>%s</th><td class=\"numeric\">$2 </td></tr>\n" "$1" "$3"
}

print_points_summary () {
    if [ $possible = 0 ]; then
        html_p 'No points possible.'
        echo 0.01
        return
    fi

    html_try_close_test_case
    printf '<table class="points-summary">'
    printf '<colgroup><col/><col/></colgroup>'
    printf '<thead><tr><th colspan="2">Summary</th></tr></thead>\n'
    printf '<tbody>'
    points_summary_tr 'Checks passed: ' %d $passed
    points_summary_tr 'Checks failed: ' %d $failed
    points_summary_tr 'Points earned: ' %d $actual
    points_summary_tr 'Points possible: ' %d $possible
    points_summary_tr 'Correctness score: ' %5.1f%% \
        $(bc_expr "100 * $actual / $possible")
    printf '</tbody>'
    printf '</table>'

    bc_expr "$actual / $possible"
}

