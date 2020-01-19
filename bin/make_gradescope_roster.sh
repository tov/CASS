#!/bin/sh

. "$(dirname "$0")/.CASS"

echo "Name,Email,NetID"

all_netids | while read netid; do
    first="$(print_student_property $netid first)"
    last="$(print_student_property $netid last)"
    email="$(print_student_property $netid email)"
    printf '"%s, %s",%s,%s\n' "$last" "$first" "$email" "$netid"
done
