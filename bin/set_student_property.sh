#!/bin/sh

. "$(dirname "$0")/.CASS"

eval "$(getargs -rc netid propname value...+)"

if [ -n "$flag_r" ]; then
    netid=$(resolve_student $netid) || exit 2
fi

if [ -n "$flag_c" ]; then
    mkdir -p "$COURSE_DB"/students/$netid
fi

printf '%s\n' "$value" > "$COURSE_DB"/students/$netid/$propname
