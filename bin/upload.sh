#!/bin/sh

# upload.sh: uploads the course web site.
#
#  -a   upload everything
#  -m   upload man pages
#  -s   upload shell stuff
#  -w   upload web site
#
# Defaults to -sw

. "$(dirname "$0")/.CASS"
eval "$(getargs -amsw)"

if [ -n "$flag_a" ]; then
    flag_m=-m
    flag_s=-s
    flag_w=-w
elif [ -z "$flag_m$flag_s$flag_w" ]; then
    flag_s=-s
    flag_w=-w
fi

assert_branch () {
    local actual
    eval "$(getargs + dir desired)"

    actual=$(cd "$dir" && git symbolic-ref HEAD) || {
        echo >&2 "repo in $dir"
        exit 1
    }

    if [ "$actual" != "$desired" ]; then
        exec >&2
        echo "$(basename $0): cannot upload from this git branch"
        if [ "$dir" != . ]; then
            echo "  in submodule: $dir"
        fi
        echo "  branch is:    $actual"
        echo "  should be:    $desired"
        exit 2
    fi
}

rsync_upload () {
    rsync \
        --compress \
        --copy-unsafe-links \
        --exclude '.nfs*' \
        --exclude '/.*' \
        --links \
        --omit-dir-times \
        --recursive \
        --times \
        --verbose \
        "$COURSE_VAR/staging/$1/" \
        "$2:$3"

    ssh "$2" chmod -R a+rX,g-w "$3"
}


upload_man () {
    : ${shell_host? needs to be set in etc/course.config}
    : ${man_update_cmd? needs to be set in etc/course.config}

    ssh "$shell_host" $man_update_cmd
}

upload_shell () {
    : ${shell_host? needs to be set in etc/course.config}
    : ${shell_path? needs to be set in etc/course.config}

    rsync_upload shell cs211@$shell_host $shell_path
}

upload_web () {
    : ${web_host? needs to be set in etc/course.config}
    : ${web_path? needs to be set in etc/course.config}

    rsync_upload web $web_host $web_path
}

cd "$COURSE_ROOT"

# assert_branch .                         refs/heads/master
# assert_branch dev/lab                   refs/heads/master
# assert_branch lib/dot-cs211             refs/heads/master
# assert_branch lib/dot-cs211/lib/ge211   refs/heads/release
# assert_branch lib/dot-cs211/lib/catch   refs/heads/master

if [ -n "$flag_w" ]; then
    upload_web &
fi

if [ -n "$flag_s" ]; then
    upload_shell &
fi

if [ -n "$flag_m" ]; then
    upload_man &
fi

wait
