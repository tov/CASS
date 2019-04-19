#!/bin/sh

. "$(dirname "$0")/../lib/common.sh"

eval "$(getargs quiz)"

quiz="$(printf 'quiz%02d' $quiz)"

file="$COURSE_DB/assignment_ids/$quiz"
if [ -f "$file" ]; then
    echo "Quiz already exists: $quiz" >&2
    exit 3
fi

curl -s "$canvas_api/assignments" \
    -X POST \
    -F "assignment[name]=$quiz" \
    -F "assignment[assignment_group_id]=$quiz_group" \
    -F "assignment[grading_type]=letter_grade" \
    -F "assignment[grading_standard_id]=$quiz_grading_standard" \
    -F "assignment[points_possible]=1" \
    -F "assignment[published]=true" \
    -H "Authorization: Bearer $CANVAS_OAUTH" |
    sed 's/{"id"://; s/,.*//; 2,$d' |
    tee "$file"
