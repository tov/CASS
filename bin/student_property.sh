#!/bin/sh

. "$(dirname "$0")/../lib/common.sh"

eval "$(getargs netid propname)"

cat "$COURSE_DB"/students/$netid*/$propname
