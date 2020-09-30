#!/bin/sh

set -eu

. "$(dirname "$0")/.CASS"
eval "$(getargs -r hw student ...)"
course_use student

signature="Jesse's Partner Notification Shell Script"

netids=
for pat in "$student" "$@"; do
    netids="$netids $(resolve_student $flag_r "$pat")" || exit
done
set -- $netids

cat <<EOF
sendmail $(email_list $*) <<'EOM'
From: "Jesse A. Tov" <jesse@cs.northwestern.edu>
To: $(format_to_line $*)
Subject: HW$hw pairs

Dear $(greeting_list $*),
EOF

if [ $# = 1 ]; then
cat <<EOF

You have been assigned no partner for Homework $hw.

EOF
else
cat <<EOF

You have been assigned as partners for Homework $hw. If one
of you drops the course, please let us know ASAP so your
partner isn't disadvantaged.

EOF
fi

cat <<EOF
Best,
$signature
EOM
EOF
