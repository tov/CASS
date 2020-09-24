#!/bin/sh

# upload.sh: uploads the course web site.
#
#  -m   upload man pages as well (-W && -S implies -m)
#  -W   skip uploading website
#  -S   skip uploading shell stuff
#  -v   verbose

. "$(dirname "$0")/.CASS"
eval "$(getargs -mWSv)"

if [ -n "$flag_W" ] && [ -n "$flag_S" ]; then
    flag_m=-m
fi

staging=$COURSE_VAR/staging

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

upload_man () {
    : ${shell_host? needs to be set in /etc/config.sh}
    : ${man_update_cmd? needs to be set in /etc/config.sh}

    ssh "$shell_host" $man_update_cmd
}

upload_shell () {
    : ${shell_host? needs to be set in /etc/config.sh}
    : ${shell_path? needs to be set in /etc/config.sh}

    rsync -avz --chmod=a+rX --delete \
        $staging/shell/ \
        cs211@$shell_host:$shell_path
}

upload_web () {
    : ${web_host? needs to be set in /etc/config.sh}
    : ${web_path? needs to be set in /etc/config.sh}

    rsync -avz --chmod=a+rX --delete \
        $staging/web/ \
        $web_host:$web_path
}

cd "$COURSE_ROOT"

# assert_branch .                         refs/heads/master
# assert_branch dev/lab                   refs/heads/master
# assert_branch lib/dot-cs211             refs/heads/master
# assert_branch lib/dot-cs211/lib/ge211   refs/heads/release
# assert_branch lib/dot-cs211/lib/catch   refs/heads/master

if [ -z "$flag_W" ]; then
    upload_web &
fi

if [ -z "$flag_S" ]; then
    upload_shell &
fi

if [ -n "$flag_m" ]; then
    upload_man &
fi

wait
