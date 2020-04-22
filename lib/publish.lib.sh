# vim: se ft=sh et sw=4:

_is_ancestor_of () {
    case "$2" in
        "$1"|"$1"/*) return 0
    esac
    return 1
}

_find_dist_files_helper () {
    git ls-files --recurse-submodules . | while read file; do
        if [ -f "$file" ]; then
            echo "$1$file"
        elif [ -d "$file" ]; then
            (
            cd "$file"
            old_wd=$new_wd
            new_wd=$(realpath "$(pwd)")

            if _is_ancestor_of "$new_wd" "$old_wd"; then
                if [ -n "$VERBOSE" ]; then
                    echo >&4 "find_dist_files: not recurring at $1$file"
                fi
            else
                _find_dist_files_helper "$1$file/"
            fi
            )
        else
            cass_error 12 "find_dist_files: can’t handle: ‘$file’"
        fi
    done
}

find_dist_files () {
    if ! [ -d "$1" ]; then
        cass_error 10 "find_dist_files: not a directory: ‘$1’"
    fi

    (
    cd "$1"
    new_wd=$(realpath "$(pwd)")
    _find_dist_files_helper ''
    )
}

FIXUP_TEMPLATE='
    1,2d
    /^$/,$d
    s| -> .*||
    s|^|%s: |
'

publish_dir () {
    local args; args=
    local deps; deps=false

    while true; do
        case "$1" in
            -G)
                args="$args --exclude ge211"
                shift
                ;;
            -d)
                args="$args --verbose --dry-run"
                deps=true
                shift
                ;;
            --)
                shift
                break
                ;;
            *)
                break
                ;;
        esac
    done

    if [ -f $1/.gitignore ]; then
        args="$args --exclude-from=$1/.gitignore"
    fi

    if ( $deps && [ $# -lt 2 ] ) || ( ! $deps && [ $# != 2 ] ); then
        echo >&4 "Usage: publish_dir [-G]    SRC DST"
        echo >&4 "Usage: publish_dir [-G] -d SRC DST..."
        return 1
    fi

    local src; src=$1; shift
    while [ -L "$src" ]; do
        src=$(readlink "$src")
    done

    local dst
    local deps_fixup
    if $deps; then
        dst=/tmp/bogus
        deps_fixup=$(printf "$FIXUP_TEMPLATE" "$*")
    else
        dst=$1
        deps_fixup=
    fi

    rsync --recursive --links --copy-unsafe-links --times \
        $args                   \
        --exclude a.out         \
        --exclude doc           \
        --exclude .DS_Store     \
        --exclude .git          \
        --exclude '*.dSYM'      \
        --exclude .gitmodules   \
        --exclude '.*.sw?'      \
        --exclude '#*'          \
        --exclude '$*'          \
        --exclude '*~'          \
        "$src" "$dst"           |
    sed "$deps_fixup"
}

