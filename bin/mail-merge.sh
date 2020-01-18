#!/bin/sh

. "$(dirname "$0")/.CASS"
course_use student

eval "$(getargs netids subject)"

template=$(mktemp -t mail-merge-template.XXXXXX) || exit 2
trap "rm -Rf $template" EXIT

cat >>$template <<'EOF'
sendmail '{EMAIL}' <<'EOM'
From: "Jesse A. Tov" <jesse@eecs.northwestern.edu>
To: "{NAME}" <{EMAIL}>
Subject: {SUBJECT}

EOF
cat >>$template
cat >>$template <<'EOF'
EOM

EOF

for netid in $(cat $netids); do
    sed "
        s/{SUBJECT}/$subject/g;
        s/{EMAIL}/$(email $netid)/g;
        s/{NAME}/$(name $netid)/g;
        s/{FIRST}/$(first - $netid)/g;
    " $template
done
