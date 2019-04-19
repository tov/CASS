#!/bin/sh

. "$(dirname "$0")/../lib/common.sh"

eval "$(getargs quiz)"

quiz="$(printf 'quiz%02d' $quiz)"

file="$COURSE_DB/assignment_ids/$quiz"
if [ -f "$file" ]; then
    quiz_id="$(cat "$file")"
else
    echo "Unrecognized quiz: $quiz" >&2
    exit 3
fi

curl -s "$canvas_api/assignments/$quiz_id" \
    -X DELETE \
    -H "Authorization: Bearer $CANVAS_OAUTH" |
    grep -v '^{"errors"' && rm "$file"

