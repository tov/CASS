#!/bin/sh

# Reads student records from stdin and writes to var/db/students

. "$(dirname "$0")/../lib/common.sh"

echo 'Input format: NetID CanvasID' >&2

while read netid canvas; do
    "$COURSE_BIN"/set_student_property.sh -c $netid canvas-id "$canvas"
done
