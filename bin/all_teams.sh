#!/bin/sh

. "$(dirname "$0")/../lib/common.sh"

eval "$(getargs hw)"

teams="$COURSE_DB/teams/$hw"

if [ -f "$teams" ]; then
    sed 's/[[:space:]]\{1,\}/-/g' "$teams"
else
    all_netids
fi
