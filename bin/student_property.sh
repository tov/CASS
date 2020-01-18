#!/bin/sh

. "$(dirname "$0")/.CASS"

eval "$(getargs -R netid propname)"

if [[ -z "$flag_R" ]]; then
    netid=$(resolve_student "$netid") || exit 2
fi

print_student_property "$netid" "$propname"
