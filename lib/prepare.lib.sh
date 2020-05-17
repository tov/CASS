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
)

generate_install_sh () {
    generate_install_sh_helper "$@" > install.sh
    chmod +x install.sh
}

generate_install_sh_helper () (
    unindent <<-'....end'
        #!/bin/sh

        dst=$HOME/bin

        install_bins () {
            for file; do
                if ! [ -x "build/$file" ]; then
                    echo >&2 "$0: skipping missing binary: $file"
                    continue
                fi

                mkdir -p "$dst"
                install -m 755 "build/$file" "$dst"
                ln -s "bin/$file" "$HOME/"
            done
        }

        if [ -d Resources ]; then
            cp -R Resources "$HOME"
        fi

....end

    printf install_bins
    for target; do
        printf " '%s'" "$(printf %s "$target" | sed "s/'/'\\\\''/g")"
    done

    echo ' && true'
    echo
)
