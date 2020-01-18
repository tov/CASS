#!/bin/sh

# upload.sh: uploads the course web site.
#
#  -m   upload man pages as well
#  -W   skip uploading website; implies -m

. "$(dirname "$0")/.CASS"
eval "$(getargs -mW)"

src=web
dst=/tmp/upload
man_host=batgirl.eecs.northwestern.edu

assert_branch () {
    local dir
    local desired
    local actual

    eval "$(getargs dir desired)"

    if ! [[ -d "$dir" ]]; then
        return
    fi

    actual=$(cd "$dir" && git symbolic-ref HEAD) || exit 1

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

cd "$COURSE_ROOT"

assert_branch .       refs/heads/master
assert_branch web/lab refs/heads/master

if [[ -n "$flag_m$flag_W" ]]; then
    if [[ -z "$MAN_HOST" ]]; then
        MAN_HOST="$man_host"
        echo >&2 "\$MAN_HOST not set; using $MAN_HOST"
    fi

    chmod -R a+rX man
    tar cp man | ssh "$MAN_HOST" 'tar xpvC pub/share'
fi

if [[ -z "$flag_W" ]]; then
    rm -Rf $dst
    trap 'rm -Rf $dst' EXIT

    "$COURSE_BIN"/publish.sh $src $dst &&
        rsync -avz --delete --chmod=a+rX $dst/ $web_host:$web_path
fi
