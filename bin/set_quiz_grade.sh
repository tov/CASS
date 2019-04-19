#!/bin/sh

. "$(dirname "$0")/../lib/common.sh"

eval "$(getargs quiz netid score ...)"

quiz="$(printf 'quiz%02d' $quiz)"

file="$COURSE_DB/assignment_ids/$quiz"
if [ -f "$file" ]; then
    quiz_id="$(cat "$file")"
else
    echo "Unrecognized quiz: $quiz" >&2
    exit 3
fi

netid=$(resolve_student "$netid") || exit 4
user_id=$("$COURSE_BIN/student_property.sh" "$netid" canvas-id) || exit 5
# user_id=82067 # test student

curl -s "$canvas_api/assignments/$quiz_id/submissions/$user_id" \
    -X PUT \
    -F "submission[posted_grade]=$score" \
    -F "comment[text_comment]=$*" \
    -H "Authorization: Bearer $CANVAS_OAUTH"

