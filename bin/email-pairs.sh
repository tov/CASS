#!/bin/sh

. "$(dirname "$0")/.CASS"
course_use student

eval "$(getargs hw)"

cat "$COURSE_DB/teams/$hw" | while read team a b c; do

if [ -n "$c" ]; then
cat <<EOF
sendmail $(email $a) $(email $b) $(email $c) <<'EOM'
From: "Jesse A. Tov" <jesse@cs.northwestern.edu>
To: "$(name $a)" <$(email $a)>, "$(name $b)" <$(email $b)>, "$(name $c)" <$(email $c)>
Subject: HW$hw groups

Dear $(name $a), $(name $b), and $(name $c),

You have been assigned as partners for Homework $hw.

Best,
Jesse
EOM
EOF
elif [ -n "$b" ]; then
cat <<EOF
sendmail $(email $a) $(email $b) <<'EOM'
From: "Jesse A. Tov" <jesse@cs.northwestern.edu>
To: "$(name $a)" <$(email $a)>, "$(name $b)" <$(email $b)>
Subject: HW$hw pairs

Dear $(name $a) and $(name $b),

You have been assigned as partners for Homework $hw. If one of you drops
the course, please let us know ASAP so your partner isn't disadvantaged.

Best,
Jesse
EOM
EOF
else
cat <<EOF
sendmail $(email $a)  <<'EOM'
From: "Jesse A. Tov" <jesse@cs.northwestern.edu>
To: "$(name $a)" <$(email $a)>
Subject: HW$hw pairs

Dear $(name $a),

You have been assigned no partner for Homework $hw.

Best,
Jesse
EOM
EOF
fi

done
