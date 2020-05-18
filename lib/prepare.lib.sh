NO_CHANGE_MARKER="* DO NOT CHANGE ANYTHING IN THIS FILE *"
NO_CHANGE_ABOVE_RE="[*] DO NOT CHANGE ANYTHING ABOVE THIS LINE [*]"

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

repair_starter_file () (
    starter_dir=$(find_homework $1)/starter
    file=$2
    saved=$file.saved
    original=$starter_dir/$file

    if ! [ -f $file ] || cmp -s $file $original; then
        return
    fi

    marker_line=$(sed "/$NO_CHANGE_ABOVE_RE/q" $original | wc -l)

    mv $file $saved

    {
        sed "${marker_line}q"   $original
        sed "1,${marker_line}d" $saved
    } > $file

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

        if [ -d Resources ]; then
            install_dir Resources "$HOME/Resources" "$@"
        fi

....end

    for target; do
        printf 'install_bin "%s" "$@"\n' \
            "$(printf %s "$target" | sed "s/'/'\\\\''/g")"
    done
)
