# For printing announcements/messages/logging

exec 3>&1
QUIET=
go_quiet () {
    QUIET=:
    exec >/dev/null
}

msgf () {
    printf >&3 "$@"
}

announce () {
    local fmt; fmt=$1; shift
    if [ -n "$QUIET" ]; then
        if [ "$fmt" = -Q ]; then
            return 0
        fi
        msgf "$fmt\n" "$@"
    else
        if [ "$fmt" = -Q ]; then
            fmt=$1
            shift
        fi
        msgf "\n*** $fmt\n" "$@"
    fi
}

doing () {
    Current_doing=$(printf "$@")
    current_doing=$(printf %s "$Current_doing" | tr A-Z a-z)

    if [ -n "$QUIET" ]; then
        msgf ' + %s... ' "$current_doing"
    else
        msgf '\n+++ %s...\n' "$Current_doing"
    fi

    doing_start=$(current_millis)
}

did () {
    test -n "$current_doing" || return 0

    if [ -n "$QUIET" ]; then
        msgf '%s (%s).\n' "${1:-done}" "$(elapsed_since $doing_start)"
    else
        msgf '\n+++ %s %s in %s.\n\n' \
            "$Current_doing" \
            "${1:-done}" "$(elapsed_since $doing_start)"
    fi

    current_doing=
}

current_millis () {
    date +%s%03N
}

elapsed_since () {
    elapsed_millis=$(( $(current_millis) - $1 ))
    elapsed_seconds=$(( elapsed_millis / 1000 ))
    subsecond_millis=$(( elapsed_millis % 1000 ))
    printf '%d.%03d s' $elapsed_seconds $subsecond_millis
}

