# Library for quoting text

del_char="$(printf '\x7F')"
shell_dq_chars='\\$!`"'
shell_bs_chars='][[:space:]|&;()<>{}*?~'"'${shell_dq_chars}"

_sed_shell_sq='
    s/'\''/&\\&&/g
    1s/^/'\''/
    $s/X$/'\''/
'

_sed_shell_dq='
    s/['"$shell_dq_chars"']/\\&/g
    1s/^/"/
    $s/X$/"/
'

_sed_shell_bs='
    s/['"$shell_bs_chars"']/\\&/g
    ${s/X$//; q;}
    s/$/\\/
'

sh_sq () {
    printf %sX "$1" | sed "$_sed_shell_sq"
}

sh_dq () {
    printf %sX "$1" | sed "$_sed_shell_dq"
}

sh_bs () {
    printf %sX "$1" | sed "$_sed_shell_bs"
}

shell_quote () {
    if ! expr "$1" : ".*[$shell_bs_chars]" >/dev/null; then
        printf '%s\n' "$1"
    elif ! expr "$1" : ".*'" >/dev/null; then
        sh_sq "$1"
    else
        sh_dq "$1"
    fi
}

shell_quote_words () {
    printf '%s' "$(shell_quote "$1")"
    while (( $# > 1 )); do
        shift
        printf ' %s' "$(shell_quote "$1")"
    done
    echo
}

c_quote_string () {
    printf '%s\n' "$2"          |
        ubsed -E '
            s/\\/&&/g
            s/'"$1"'/\\&/g
            s/	/\\t/g
            s/'"$del_char"'/\\x7F/g
            2,$s/^/\\n/
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
