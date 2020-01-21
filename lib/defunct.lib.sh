# TODONE

expect_exit () {
    local points
    local op
    local expected_code

    points=1
    up_points || true

    case "$1" in
        \!*)
            op='!='
            expected_code=${1#\!}
            ;;
        *)
            op='='
            expected_code=$1
            ;;
    esac

    html_expect "exit code $op $expected_code, got $last_exitcode"
    score_if [ "$last_exitcode" $op "$expected_code" ]
}

expect_lines () {
    local points
    local correct_output
    local expected_lines
    local actual_lines
    local count_noun

    points=1
    up_points || true
    correct_output=$1; shift

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

    html_expec "$count_noun of output, got $actual_lines"
    score_if [ "$actual_lines" = "$expected_lines" ]
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
        elif line="$(strip_prefix @ "$1")"; then
            shift
            pattern="$1"; shift
            sed "$line!d" "$file" > "$file-$line"
            html_expect "$which L%d to match pattern ‘<tt>%s</tt>’" \
                "$line" "$pattern"
            score_if sgrep -i -- "^ *$pattern *\$" "$file-$line"
        elif pattern="$(strip_prefix == "$1")"; then
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
                html_expect "$which L%d to be exactly ‘</tt>%s</tt>’" \
                    "$count" "$(printf '%s' "$pattern1" | visify)"
                score_if [ "$pattern1" = "$line1" ]
            done

            if [ -n "$line" ]; then
                html_p "??? Extra output unexpected after L%d" $count
            fi
        elif pattern="$(strip_prefix = "$1")"; then
            shift
            line=$(cat "$file")
            html_expect "$which to be exactly ‘%s’" \
                "$(printf '%s' "$pattern" | visify)"
            score_if [ "$pattern" = "$line" ]
        else
            pattern="$1"; shift
            html_expect "$which to contain pattern ‘%s’" \
                    "$pattern"
            score_if sgrep -i -- "$pattern" "$file"
        fi
    done
}

tab_char=$(printf '\t')
del_char=$(printf '\177')
lf_char=$(printf '\n')

visify () {
    sed -e '
        s/\\/\\\\/g;
        s/'"$tab_char"'/\\t/g;
        s/'"$del_char"'/\\177/g;
        s/ $/\\040/;
    '
}

line_count () {
    wc -l < "$1" | tr -d ' '
}

