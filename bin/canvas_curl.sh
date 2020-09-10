#!/bin/sh

. "$(dirname "$0")/.CASS"
course_use canvasapi

if [ "$1" = --dry-run ]; then
    maybe_dry_run=--dry-run
    shift
else
    maybe_dry_run=
fi

if expr "$1" : '[[:alpha:]][[:alpha:]]*$' >/dev/null; then
    verb=$1
    shift
else
    verb=get
fi

canvas_curl $maybe_dry_run $verb "$@" --show-error
