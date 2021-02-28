NO_CHANGE_MARKER='* DO NOT CHANGE ANYTHING IN THIS FILE *'
NO_CHANGE_ABOVE='DO NOT CHANGE ANYTHING ABOVE THIS LINE'
NO_CHANGE_ABOVE_RE="[*] ${NO_CHANGE_ABOVE} [*]"

restore_starter_files () (
    starter_dir=$(find_homework $1)/starter
    restore_starter_files_from "$starter_dir" src
    restore_starter_files_from "$starter_dir" test
)

restore_starter_files_from () {
    find "$1/$2" -type f | while read file; do
        if head -2 "$file" | fgrep -q "$NO_CHANGE_MARKER"; then
            rsync --times "$file" "$2/"
        fi
    done
}

same_above_line () {
    local line=$1 a=$2 b=$3

    local ta=$(mktemp -t prepare_lib_a.XXXXXX)
    trap "rm -f '$ta'"       RETURN
    local tb=$(mktemp -t prepare_lib_b.XXXXXX)
    trap "rm -f '$ta' '$tb'" RETURN

    head -$line "$a" > "$ta"
    head -$line "$b" > "$tb"

    diff "$ta" "$tb" >/dev/null
}

repair_starter_file () (
    starter_dir=$(find_homework $1)/starter
    file=$2
    saved=$file.saved
    original=$starter_dir/$file

    if ! [ -f $file ] || cmp -s $file $original; then
        return
    fi

    mv $file $saved

    marker_line=$(sed "/$NO_CHANGE_ABOVE_RE/q" $original | wc -l)

    if same_above_line $marker_line $original $saved; then
        sed "${marker_line}q"   $original
        sed "1,${marker_line}d" $saved
    else
        unindent . >&2 <<........END
        WARNING: It appears that file ‘$file’ has been changed
        above the line that says:

       .    $NO_CHANGE_ABOVE

        I am replacing the version of ‘$file’ that you submitted
        with the version from the starter code. This means it is
        likely that I won’t be able to build your code.

........END
        cat $original
    fi > $file

    touch -m -r $saved $file
)

generate_install_sh () {
    generate_install_sh_helper "$@" > install.sh
    chmod +x install.sh
}

generate_install_sh_helper () (
    unindent <<-'....end'
        #!/bin/sh

        set -e

        depend_on () {
            $do_deps || return 0

            local input; input=$1; shift

            echo "$input:"

            while [ $# -gt 0 ]; do
                case "$1" in
                    -d)
                        echo "$2: $input"
                        shift; shift
                        ;;
                    -d*)
                        echo "${1#-d}: $input"
                        shift
                        ;;
                    *)
                        break
                        ;;
                esac
            done
        }

        install_bin () {
            local file; file=$1; shift

            local dst; dst=$HOME/bin
            local src; src=build/$file
            depend_on "$src" "$@"

            if ! [ -x "$src" ]; then
                echo >&2 "$0: skipping missing binary: $file"
                return 0
            fi

            mkdir -p "$dst"
            install -m 755 "$src" "$dst"
            ln -s "bin/$file" "$HOME/"
        }

        dir_is_empty () {
            ! test -d "$1" ||
                find "$1" -maxdepth 0 -empty |
                    read >/dev/null 2>&1
        }

        install_dir () {
            local src; src=$1; shift
            local dst; dst=$1; shift

            mkdir -p "$dst"
            depend_on "$src" "$@"

            local file
            for file in $src/*; do
                if [ -d "$file" ]; then
                    echo >&2 "Skipping nested directory: $file"
                    continue
                fi

                install -m 644 "$file" "$dst"
                depend_on "$file" "$@"
            done
        }

        do_deps=false
        for arg; do
            case "$arg" in
                -d*)
                    do_deps=true
                    break
            esac
        done

        if dir_is_empty Resources; then
            depend_on "$src" "$@"
        else
            install_dir Resources "$HOME/Resources" "$@"
        fi

....end

    for target; do
        printf 'install_bin "%s" "$@"\n' \
            "$(printf %s "$target" | sed "s/'/'\\\\''/g")"
    done
)
