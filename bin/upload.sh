#!/bin/sh

# upload.sh: uploads the course web site.
#
#  -m   upload man pages as well
#  -W   skip uploading website; implies -m
#  -v   verbose

. "$(dirname "$0")/.CASS"
eval "$(getargs -mWv)"

src=web
tempdir=/tmp/upload

remove_tempdir () {
    rm -Rf $tempdir
}

assert_branch () {
    local actual
    eval "$(getargs + dir desired)"

    actual=$(cd "$dir" && git symbolic-ref HEAD) || {
        echo >&2 "repo in $dir"
        exit 1
    }

    if [[ "$actual" != "$desired" ]]; then
        exec >&2
        echo "$(basename $0): cannot upload from this git branch"
        if [[ "$dir" != . ]]; then
            echo "  in submodule: $dir"
        fi
        echo "  branch is:    $actual"
        echo "  should be:    $desired"
        exit 2
    fi
}


upload_man_pages () {
    : ${man_host? needs to be set in /etc/config.sh}
    : ${man_update_cmd? needs to be set in /etc/config.sh}
    ssh "$man_host" $man_update_cmd
}

upload_website () {
    remove_tempdir
    register_exit_function remove_tempdir

    "$COURSE_BIN"/publish.sh $flag_v $src $tempdir &&
    rsync -avz --delete --chmod=a+rX $tempdir/ $web_host:$web_path
}

cd "$COURSE_ROOT"

assert_branch .                         refs/heads/master
assert_branch dev/lab                   refs/heads/master
assert_branch lib/dot-cs211             refs/heads/master
assert_branch lib/dot-cs211/lib/ge211   refs/heads/release
assert_branch lib/dot-cs211/lib/catch   refs/heads/master

if [[ -n "$flag_m$flag_W" ]]; then
    upload_man_pages
fi

if [[ -z "$flag_W" ]]; then
    upload_website
fi

