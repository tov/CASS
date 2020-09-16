# for doing dry runs

course_use quote

dry_run_if () {
    if "$@"; then
        _N () {
            printf '> '
            shell_quote_words "$@"
        } >&2
    else
        _N () {
            "$@"
        }
    fi
}
