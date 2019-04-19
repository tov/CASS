#!/bin/sh

. "$(dirname "$0")/../lib/common.sh"

cd "$COURSE_ROOT"

src=web
dst=/tmp/upload

rm -Rf $dst
"$COURSE_BIN"/publish.sh $src $dst &&
    rsync -avz --delete --chmod=a+rX $dst/ $web_host:$web_path
rm -Rf $dst
