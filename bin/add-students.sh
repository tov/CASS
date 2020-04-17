#!/bin/sh

# Reads student records from stdin and writes to var/db/students

. "$(dirname "$0")/.CASS"

echo 'Input format: NetID Email Last Name,First Name' >&2

while read netid email name; do
    netid="$(echo $netid | tr A-Z a-z)"
    last="$(echo "$name" | sed 's/,.*//')"
    first="$(echo "$name" | sed 's/.*,//')"
    "$COURSE_BIN"/set_student_property.sh -c "$netid" email "$email"
    "$COURSE_BIN"/set_student_property.sh "$netid" last "$last"
    "$COURSE_BIN"/set_student_property.sh "$netid" first "$first"
    print_student_info "$netid"
done
