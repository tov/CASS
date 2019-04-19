#!/bin/sh

. "$(dirname "$0")/../lib/common.sh"

eval "$(getargs quiz csv)"

"$COURSE_BIN/parse_gradescope.hs" < "$csv" |
    sed "s@^@'$COURSE_BIN/set_quiz_grade.sh' $quiz @" |
    sh
