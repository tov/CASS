# For printing announcements/messages/logging

msgf () {
    printf >&4 "$@"
}

announce () {
    if [ -n "$QUIET" ]; then
        msgf '%s\n' "$(printf "$@")"
    else
        msgf '\n*** %s\n' "$(printf "$@")"
    fi
}

doing () {
    current_doing=$(printf "$@" | tr A-Z a-z)

    if [ -n "$QUIET" ]; then
        msgf ' + %s... ' "$current_doing"
    else
        msgf '\n+++ %s...\n' "$(printf "$@")"
    fi

    doing_start=$(current_millis)
}

did () {
    if [ -n "$QUIET" ]; then
        msgf 'done (%s).\n' "$(elapsed_since $doing_start)"
    else
        msgf '\n+++ Done %s in %s.\n\n' \
            "$current_doing" \
            "$(elapsed_since $doing_start)"
    fi
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

