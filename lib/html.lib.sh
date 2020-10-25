# HTML output for grading.

del_char=$(printf '\x7F')
esc_char=$(printf '\x1B')

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

html_test_case () {
    html_try_close_test_case

    local outcome
    local attr
    if [ "$1" = "$2" ]; then
        outcome=passed
        attr=
    else
        outcome=failed
        attr='open="open"'
    fi


    printf '<details class="test-case" %s>\n' "$attr"
    printf '<summary>'
    textf '=====\n'
    textf '===== '

    printf '<h3 class="%s">' "$outcome"
    printf '<span>(<em>%s</em> / <em>%s</em>)</span> ' "$1" "$2"
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

html_test_result_no_points () {
    printf '<h4 class="test-result %s"><strong><span class="txt-only">%s </span>%s</strong></h4>\n\n' "$1" "$2" "$3"
}

html_test_result_with_points () {
    if [ "$5" = 1 ]; then
        printf "$test_result_tmpl1" "$1" "$2" "$3" "$4" "$5"
    else
        printf "$test_result_tmplN" "$1" "$2" "$3" "$4" "$5"
    fi
}

test_result_tmpl_tmpl='<h4 class="test-result %%s"><strong><span class="txt-only">%%s </span>%%s</strong> (%%s / %%s %s)</h4>\\n\\n'
test_result_tmpl1=$(printf "$test_result_tmpl_tmpl" point)
test_result_tmplN=$(printf "$test_result_tmpl_tmpl" points)

if [ -n "$NO_POINTS_MODE" ]; then
    alias html_test_result=html_test_result_no_points
else
    alias html_test_result=html_test_result_with_points
fi

html_test_passed () {
    html_test_result passed +++ Passed "$1" "$1"
}

html_test_failed () {
    html_test_result failed --- Failed 0 "$1"
}

html_io_lines () {
    local tag
    tag="<span class=\"$2\"><span class=\"txt-only\">$1 </span>"

    printf '<code class="io-lines">'

    html_escape | ubsed -E '
        ${
            /^%$/d
            s@%$@<span class="no-newline">%</span>@
        }
        :loop
        /([[:space:]])([[:space:]]*)$/{
            s@@<span class="trailing-ws">\1</span>\2@
            bloop
        }
        s@'"$del_char"'@<span class="control-char">\\x7F</span>@g
        s@'"$esc_char"'@<span class="control-char">\\x1B</span>@g
        s@.*@'"$tag"'&</span>@
    ' | sanitize_utf8

    echo '</code>'
}

sanitize_utf8 () {
    if which uconv >/dev/null 2>&1; then
        uconv --callback escape-unicode \
              -f UTF-8 -t UTF-8
    else
        iconv --byte-subst='<span class="invalid-byte">\x%X</span>' \
              -f UTF-8 -t UTF-8
    fi
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
