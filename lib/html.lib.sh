# HTML output for grading.

html_escape () {
    ubsed -E '
        s@&@\&amp;@g
        s@<@\&lt;@g
        s@>@\&gt;@g
        s@"@\&quot;@g
    '
}

sed_html_unescape_prog='
    s@&lt;@<@g
    s@&gt;@>@g
    s@&quot;@"@g
    s@&amp;@\&@g
'

sed_html_untag_prog='
    s/<[^>]*>//g
'

unhtml () {
    ubsed "$@" -E "
        $sed_html_unescape_prog
        $sed_html_untag_prog
    "
}

capture_test_results () {
    tee ${1%.*}.hlog |
        unhtml -l |
        ubsed -E '
            s/==[[:digit:]]+==ERROR/=======ERROR/
            s/0x[0-9a-f]{4}/0x..../g
            :loop
                s/(0x[.]{4,})[0-9a-f]/\1./g
            tloop
        ' |
        tee ${1%.*}.log
}

last_text_fmt=
textf () {
    last_text_fmt=$(printf '<span class="txt-only">%s</span>' "$1")
    shift
    printf "$last_text_fmt" "$@"
}

html_p () {
    printf '<p>%s</p>\n' "$*" | fmt
    echo
}

html_in_test_case=false

html_try_close_test_case () {
    if $html_in_test_case; then
        echo '</div></details>'
        html_in_test_case=false
    fi
}

# Usage: html_test_case ACTUAL POSSIBLE TITLE
html_test_case () {
    html_try_close_test_case

    local detail_attr=
    local outcome_class

    if [ -n "${HTML_DETAILS_OPEN-}" ]; then
        detail_attr='open="open"'
    fi

    if [ "$1" = "$2" ]; then
        outcome_class=passed
    else
        detail_attr='open="open"'
        outcome_class=failed
    fi

    printf '<details class="test-case" %s>\n' "$detail_attr"
    printf '<summary>'
    textf '=====\n'
    textf '===== '

    printf '<h3 class="%s">' "$outcome_class"
    if [ "$2" = 0 ]; then
        printf '<span>(<em>not for points</em>)</span>' "$1" "$2"
    elif [ -n "$NO_POINTS_MODE" ]; then
        printf '<span>(<em>early run</em>)</span>'
    else
        printf '<span>(<em>%s</em> / <em>%s</em>)</span> ' "$1" "$2"
    fi
    textf ' '
    printf '%s' "$3"
    printf '</h3>\n'

    printf '</summary>'
    textf '=====\n'
    printf '<div class="test-case-body">\n'
    html_in_test_case=true
}

html_subhead () {
    textf '=== '
    printf '<h4>%s</h4>\n\n' "$*"
}

html_errorhead () {
    textf '!!! '
    printf '<h4 class="error">%s</h4>\n\n' "$*"
}

test_result_points_tmpl='<strong><span class="txt-only">%s </span>%s</strong> (%s / %s %s)</h4>\\n\\n'
test_result_no_points_tmpl='<h4 class="test-result %s"><strong><span class="txt-only">%s </span>%s</strong></h4>\\n\\n'

print_html_test_result () {
    printf '<h4 class="test-result %s">' "$1"
    printf '<strong><span class="txt-only">%s </span>%s</strong>' "$2" "$3"

    if [ -z "$NO_POINTS_MODE" ] && [ "$5" -gt 0 ]; then
        printf ' (%s / %s %s)' "$4" "$5" "$(pluralize "$5" point)"
    fi

    printf '</h4>\n\n'
}

html_test_passed () {
    print_html_test_result passed +++ Passed "$1" "$1"
}

html_test_failed () {
    print_html_test_result failed --- Failed 0 "$1"
}

html_io_lines () {
    echo '<code class="io-lines">'
    "${COURSE_BIN}"/html_io_lines "$@"
    echo '</code>'
}

ccgo_open='<code class="grep-output">'
ccgo_close='</code>'
ccgo_clopen=$ccgo_close$ccgo_open

html_grep_output () {
    local pat; pat=$1
    local sedprog

    sedprog='
        \@^--$@{
            :again
            N
            s/^--\n//
            /^--$/bagain
            s@^@'$ccgo_clopen'@
        }

        \@^('$ccgo_clopen')?([[:digit:]]*)[:-](.*)$@{
            s@@\1<small>\2</small> \3@
            s@'$pat'@<strong>&</strong>@g
            bdone
        }

        s@.*@<strong>&</strong>@

        :done
    '

    printf "$ccgo_open"
    html_escape | ubsed -E "$sedprog"
    printf "$ccgo_close"
}
