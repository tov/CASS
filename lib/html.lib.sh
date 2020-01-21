# HTML output for grading.

html_tag_line () {
    local tag; tag=$1; shift
    local fmt; fmt=$1; shift
    local end; end=$(echo "$tag" | sed 's/ .*//')
    printf "<$tag>$fmt</$end>\n" "$@"
}

html_p () {
    local fmt; fmt=$1; shift
    printf "<p>$fmt</p>\n" "$@"
}

html_expect () {
    local fmt; fmt=$1; shift
    html_p "Expecting $fmt." "$@"
}

html_check () {
    local fmt; fmt=$1; shift
    html_p "Checking $fmt." "$@"
}

html_in_test_case=false

trap '! $html_in_test_case || html_try_close_test_case' EXIT

html_try_close_test_case () {
    if $html_in_test_case; then
        echo '</div></div>'
        html_in_test_case=false
    fi
}

html_test_case () {
    html_try_close_test_case
    echo '<div class="test-case">'
    html_in_test_case=true
    html_tag_line h3 "$@"
    echo '<div class="test-case-body">'
}

html_subhead () {
    html_tag_line h4 "$@"
}

html_test_result () {
    html_tag_line "h4 class=\"test-result $1\"" "$2"
}

html_escape () {
    sed -E '
        s@&@\&amp;@g
        s@<@\&lt;@g
        s@>@\&gt;@g
        s@"@\&quot;@g
    '
}

html_io_lines () {
    printf '<code class="io_lines">'
    html_escape | sed -E '
        s@^: (.*)@<span class="stdlog">\1</span>@
        s@^! (.*)@<span class="stderr">\1</span>@
        s@^&gt; (.*)@<span class="stdout">\1</span>@
        s@^&lt; (.*)@<span class="stdin">\1</span>@
        tdone
        /^[[:space:]]*$/d
        s@.*@<span class="unknown">&</span>@
        :done
    '
    echo '</code>'
}

html_grep_output () {
    printf '<code class="grep_output">'
    html_escape | sed -E '
        /^--$/{
            N
            s@.*\n@</code><code class="grep_output">@
            bdone
        }
        s@^([[:digit:]]*)[:-](.*)$@<small>\1</small> \2@
        tokay
        s@.*@<strong>&</strong>@
        tdone
        :okay
        s@'"$pat"'@\1<strong>\2</strong>@g
        :done
    '
    printf '</code>'
}
