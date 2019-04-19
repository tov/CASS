#!/bin/sh

. "$(dirname "$0")/../lib/common.sh"

echo "Name,Email,NetID"

"$COURSE_BIN/all_students.sh" | while read netid; do
    first="$("$COURSE_BIN/student_property.sh" $netid first)"
    last="$("$COURSE_BIN/student_property.sh" $netid last)"
    email="$("$COURSE_BIN/student_property.sh" $netid email)"
    printf '"%s, %s",%s,%s\n' "$last" "$first" "$email" "$netid"
done
