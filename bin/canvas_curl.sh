#!/bin/sh

. "$(dirname "$0")/.CASS"
course_use canvasapi

case $1 in
    --dry-run)
        maybe_dry_run=--dry-run
        shift
        ;;
    --students)
        canvas_api_list_students
        exit
        ;;
    *)
        maybe_dry_run=
        ;;
esac

if expr "$1" : '[[:alpha:]][[:alpha:]]*$' >/dev/null; then
    verb=$1
    shift
else
    verb=get
fi

canvas_curl $maybe_dry_run $verb "$@" --show-error
