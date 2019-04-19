#!/bin/sh

. "$(dirname "$0")/../lib/common.sh"

eval "$(getargs -c netid propname value)"

if [ -n "$flag_c" ]; then
    mkdir -p "$COURSE_DB"/students/$netid
else
    netid=$(resolve_student $netid) || exit 2
fi

printf '%s\n' "$value" > "$COURSE_DB"/students/$netid/$propname
