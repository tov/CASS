# helpers for HTTP APIs

get_all_pages () {
    local get; get="$1"; shift
    local uri; uri="$1"; shift

    local tmp; tmp=$(mktemp -t cass-headers.XXXXXX)
    trap "rm -f '$tmp'" RETURN

    while [ -n "$uri" ]; do
        $get "$uri" -D"$tmp" "$@"
        uri="$(extract_rel_link next <"$tmp")"
        cat /dev/null >|"$tmp"
    done
}

extract_rel_link () {
    sed '
        /^link: .*<\([^>]*\)>; *rel="'"$1"'".*/I ! d
        s//\1/
    '
}
