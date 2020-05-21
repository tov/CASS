# For printing announcements/messages/logging

exec 3>&1
QUIET=
go_quiet () {
    QUIET=:
    exec >/dev/null
}


ansi_color () {
    printf '\e[%sm' "$1"
}

msgf () {
    printf >&3 "$@"
}

note () {
    local fmt; fmt=$1; shift
    if [ -n "$QUIET" ]; then
        if [ "$fmt" = -Q ]; then
            return 0
        fi
        if_tty fmt COLOR_GRAY
        msgf "[$fmt] " "$@"
    else
        if [ "$fmt" = -Q ]; then
            fmt=$1
            shift
        fi
        if_tty fmt COLOR_GRAY
        msgf "=== [$fmt]\n" "$@"
    fi
}

announce () {
    local fmt; fmt=$1; shift
    if [ -n "$QUIET" ]; then
        if [ "$fmt" = -Q ]; then
            return 0
        fi
        if_tty fmt COLOR_BRIGHT
        msgf "$fmt\n" "$@"
    else
        if [ "$fmt" = -Q ]; then
            fmt=$1
            shift
        fi
        if_tty fmt COLOR_BLUE
        msgf "$fmt\n" "$@"
    fi
}

bg_doing () {
    if [ -n "$QUIET" ]; then
        did forked
    else
        msgf '[forked]\n'
        current_bg_doing=$current_doing
        current_doing=
    fi
}

bg_did () {
    test -n "$current_bg_doing" || return 0

    msgf '%s complete in %s.\n' \
        "$current_bg_doing" \
        "$(elapsed_since $doing_start)"
}

alias doing='trap "did \"error return\"" RETURN; _doing_helper'

_doing_helper () {
    Current_doing=$(printf "$@")
    current_doing=$(printf %s "$Current_doing" | tr A-Z a-z)

    if [ -n "$QUIET" ]; then
        msgf ' + %s... ' "$current_doing"
    else
        msgf ' + %s...\n' "$Current_doing"
    fi

    doing_start=$(current_millis)
}

did () {
    test -n "$current_doing" || return 0

    if [ -n "$QUIET" ]; then
        msgf '%s (%s).\n' "${1:-done}" "$(elapsed_since $doing_start)"
    else
        msgf ' - %s %s in %s.\n' \
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

hilite () {
    if [ -n "$(tty)" ]; then
        sed12 \
            "s/^(.{0,76}).*/    ${COLOR_GRAY}\\1${COLOR_NORMAL}/" \
            "s/^(.{0,76}).*/    ${COLOR_YELLOW}\\1${COLOR_NORMAL}/" \
            "$@"
    else
        sed12 "s/^/  › /" "s/^/  » /" "$@"
    fi 2>&1
}

sed12 () {
    local sed1; sed1=$1; shift
    local sed2; sed2=$1; shift

    {
        "$@" 2>&1 1>&3 | ubsed -E "$sed2" 1>&2
    } 3>&1 | ubsed -E "$sed1"
}

if_tty () {
    if [ -n "$(tty)" ]; then
        eval "$1=\$$2\$$1\$${3:-COLOR_NORMAL}"
    fi
}

COLOR_NORMAL=$(ansi_color 0)
COLOR_BLUE=$(ansi_color '0;34')
COLOR_RED=$(ansi_color '0;31')
COLOR_YELLOW=$(ansi_color '0;33')
COLOR_GRAY=$(ansi_color '0;2')
COLOR_BRIGHT=$(ansi_color '0;1')

