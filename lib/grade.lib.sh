# Library for grading based on running programs and matching output

: ${COURSE_GRADE_TIMEOUT:=5}
: ${COURSE_MAX_OUTPUT:=10000}
export COURSE_GRADE_TIMEOUT COURSE_MAX_OUTPUT

build_log=build.log
tests_log=tests.log
tests_hlog=tests.hlog

lf_char='
'
del_char=$(printf '\x7F')
tab_char=$(printf '\t')

current_tag=0

course_use docker html points
# TODO: remove?
course_use find

tester_on_exit () {
    if $html_in_test_case; then
        print_points_summary
    fi
}

register_exit_function tester_on_exit

auto_files_to_rm=

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

        program_test "$command" "$in_arg" "$msg_arg" \
            "$code_arg" "$err_arg" "$out_arg" "$log_arg"
    done
}

file_size () {
    wc -c "$1" | awk '{print $1}'
}

evaluate_input_param () {
    {
        case "$1" in
            :*)
                printf -- "${1#:}"
                ;;
            =*)
                printf -- %s "${1#=}"
                ;;
            \!*)
                ${1#!}
                ;;
            *)
                cat "$1"
                ;;
        esac

        if [ "$3" = % ]; then
            echo %
        fi
    } >> "$2"
}

get_param_helper () {
    case "$1" in
        ??)
            p=$2
            false
            ;;
        -?*)
            p=${1#-?}
            true
            ;;
    esac
}

alias get_param='get_param_helper "$@" || shift; shift'

shellsafe_print () {
    printf '%s' "$1" | sed "
        s/'/'\\\\''/g
        s/^/'/
        s/\$/'/
    " | tr -d '\n'
}

do_later () {
    {
        shellsafe_print "$1"
        while shift; do
            printf ' '
            shellsafe_print "$1"
        done
        printf '\n'
    } >> "$check_sh"
}

skip_program_test () {
    (( ++current_tag ))
}

program_test () {
    local command;      command=$1; shift
    local realcmd;      realcmd=$command
    local tag;          tag=$(( current_tag++ ))
    local casename;     casename=$(echo "$command" | sed 's%[/ ]%@%g')
    local prefix;       prefix=$(printf 'logs/%03d-%s' $tag "$casename")
    local docker_opts;  docker_opts=

    local check_sh;     check_sh=$prefix.check.sh
    local message;      message=$prefix.msg

    local old_points;   old_points=${points:-1}
    local points;       points=$old_points

    local act_both;     act_both=$prefix.act-both
    local act_in;       act_in=$prefix.act-in
    local act_out;      act_out=$prefix.act-out
    local act_err;      act_err=$prefix.act-err
    local act_log;      act_log=$prefix.act-log
    local act_exitcode; act_exitcode=$prefix.act-exitcode

    local exp_out;      exp_out=$prefix.exp-out
    local exp_err;      exp_err=$prefix.exp-err
    local exp_log;      exp_log=$prefix.exp-log
    local exp_exitcode; exp_exitcode=

    rm -Rf logs
    mkdir logs
    touch "$act_in"

    local p
    local np; np=$points

    while [ -n "$1" ]; do
        case "$1" in
            # ignoring emptyish arguments makes it easier to forward
            # optional arguments.
            -|'')
                shift
                ;;
            +*)
                np=${1#+}
                shift
                ;;
            -x*)
                get_param
                realcmd=$p
                ;;
            -m*)
                get_param
                evaluate_input_param "$p" "$message"
                ;;
            -0*)
                get_param
                evaluate_input_param "$p" "$act_in"
                ;;
            -1*)
                get_param
                evaluate_input_param "$p" "$exp_out" %
                do_later check_output $np "$exp_out" "$act_out" stdout
                ;;
            -2*)
                get_param
                evaluate_input_param "$p" "$exp_err" %
                do_later check_output $np "$exp_err" "$act_err" stderr
                ;;
            -3*)
                get_param
                evaluate_input_param "$p" "$exp_log" %
                do_later check_output $np "$exp_log" "$act_log" 'test log'
                ;;
            -c*)
                get_param
                do_later check_exitcode $np "=$p"
                ;;
            -C*)
                get_param
                do_later check_exitcode $np "≠$p"
                ;;
            -d*)
                get_param
                docker_opts="$docker_opts $p"
                ;;
            *)
                echo >&2 "I don't understand: ‘$1’"
                shift
                ;;
        esac
    done

    docker_test "$realcmd" "$act_exitcode" $docker_opts \
        <"$act_in" >"$act_both" 2>"$act_log"

    sed '/^1 /!d; s/^..//' "$act_both" >|"$act_out"
    sed '/^2 /!d; s/^..//' "$act_both" >|"$act_err"
    last_exitcode=$(cat "$act_exitcode")

    html_test_case Test case $tag: \
        "<code class='filename'>./$command</code>"

    if [ -f "$message" ]; then
        html_p "$(cat "$message")"
    fi

    html_subhead Input:
    html_io_lines '‹' stdin < "$act_in"

    display_output '›' stdout 'Standard Output' "$exp_out" "$act_out"
    display_output '»' stderr 'Standard Error'  "$exp_err" "$act_err"
    display_output ':' stdlog 'Test Log'        "$exp_log" "$act_log"

    check_last_exitcode

    . "$check_sh"

    last_stdout=$act_out
    last_stderr=$act_err
    last_stdlog=$act_log
}

check_exitcode () {
    local points; points=$1; shift
    case "$1" in
        =*)
            set -- "${1#=}"
            html_p Checking that exit code == $1.
            score_if [ "$1" = "$last_exitcode" ]
            ;;
        '≠'*)
            set -- "${1#≠}"
            html_p Checking that exit code \!= $1.
            score_if [ "$1" != "$last_exitcode" ]
            ;;
    esac

}

# $1: sigil             '»'
# $2: class             stderr
# $3: stream name       'Standard Error'
# $4: expected (file)   "$exp_err"
# $5: actual (file)     "$act_err"
display_output () {
    if [ -f "$4" ]; then
        html_subhead Expected $3:
        html_io_lines "$1" "$2" <"$4"
    fi

    if [ -f "$4" ] || [ "$(file_size "$5")" -gt 2 ]; then
        html_subhead Actual $3:
        html_io_lines "$1" "$2" <"$5"
    fi
}

check_output () {
    local points; points=$1
    html_p Comparing actual $4 to expected $4.
    score_if cmp -s "$2" "$3"
}

check_last_exitcode () {
    case "$last_exitcode" in
        '')
            echo>&2 Blank exit code\?
            exit 10
            ;;

        0)
            html_subhead Exit Code: '<em class="exit-success">0</em>'
            ;;

        124)
            html_errorhead Timeout Error
            html_p Your code was still running after \
                $COURSE_GRADE_TIMEOUT s, so I killed it.
            html_p You might have an infinite loop.
            ;;

        125)
            html_errorhead Excessive Output Error
            html_p Your code produced more than $COURSE_MAX_OUTPUT \
                bytes of output, so I killed it.
            html_p You might have an infinite loop.
            ;;

        *)
            html_subhead Exit Code: \
                '<em class="exit-error">'$last_exitcode'</em>'
            ;;
    esac
}

assert_warning_absence () {
    local points; get_points
    local filename; filename=$1; shift

    local fnb; ccb='<code class=\"filename\">'
    local fne; cce='</code>'

    local hfilename; hfilename="$fnb$filename$fne"
    local hbfilename; hbfilename="$fnb$(basename "$filename")$fbe"
    local pat; pat="^( |[^ ]*: (In function |warning: |note: ))"

    html_test_case "Checking for compilation warnings in $hbfilename"
    html_p There should not be any warnings when compiling your code.

    if egrep -sq "$pat" "$filename"; then
        egrep -n "$pat" "$filename" 2>&1 | html_grep_output "$pat" || true
        score_if false
    else
        score_if true
    fi
}

assert_function_absence () {
    local points; get_points
    local funname; funname=$1; shift
    local filename; filename=$1; shift

    local fnb; ccb='<code class=\"filename\">'
    local fne; cce='</code>'

    local hfunname; hfunname="<var>$funname</var>"
    local hfilename; hfilename="$fnb$filename$fne"
    local hbfilename; hbfilename="$fnb$(basename "$filename")$fbe"
    local pat; pat="(^|[^[:alnum:]])($funname *[(])"

    html_test_case "Checking for $hfunname in $hbfilename"
    html_p There should not be any calls to function $hfunname \
        in file $hfilename, because $hfilename should not contain code \
        that calls $hfunname directly.

    if egrep -sq "$pat" "$filename"; then
        egrep -nC2 "$pat" "$filename" 2>&1 | html_grep_output "$pat" || true
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
        html_p No points possible.
        echo 0.01
        return
    fi

    html_try_close_test_case

    printf '<table class="points-summary">'
    printf '<colgroup><col/><col/></colgroup>'
    printf '<thead><tr><th colspan="2">Summary</th></tr></thead>\n'
    printf '<tbody>\n'
    points_summary_tr 'Checks passed: ' %d $passed
    points_summary_tr 'Checks failed: ' %d $failed
    if [ -z "$NO_POINTS_MODE" ]; then
        points_summary_tr 'Points earned: ' %d $actual
        points_summary_tr 'Points possible: ' %d $possible
        points_summary_tr 'Correctness score: ' %5.1f%% \
            $(bc_expr "100 * $actual / $possible")
    fi
    printf '</tbody>\n'
    printf '</table>\n'

    if [ -n "$NO_POINTS_MODE" ]; then
        echo -
    else
        bc_expr "$actual / $possible"
    fi
}

c_quote_string () {
    printf '%s\n' "$2"          |
        sed -E '
            s/\\/&&&&/g
            s/'"$1"'/\\\\&/g
            s/	/\\\\t/g
            s/'"$del_char"'/\\\\x7F/g
            2,$s/^/\\\\n/
            1s/^/'"$1"'/
            $s/$/'"$1"'/
        '                       |
        tr -d '\n'
}


cdq () {
    c_quote_string \" "$1"
}

csq () {
    c_quote_string \' "$1"
}

detect_language () {
    if [ -f CMakeLists.txt ]; then
        echo cxx
    else
        echo c
    fi
}
