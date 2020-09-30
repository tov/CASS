#!/bin/sh

# Reads student records using fetch_roster (or a specified program
# passed as arguments) and writes to var/db/students.
#
# Options:
#
#   -c    use cached data if available rather than asking Canvas
#   -q    don’t print students while adding them
#   -D    pass --debug flag to CASS
#   -N    dry run -- don’t actually modify anything
#

set -eu
. "$(dirname "$0")/.CASS"
eval "$(getargs -cqDN json_src_command...)"

course_use dry_run
dry_run_if [ -n "$flag_N" ]

# If we aren’t told how to fetch the roster, use the `fetch_roster`
# program:
if [ $# = 0 ]; then
    set -- "$COURSE_BIN"/fetch_roster $flag_c $flag_D --json
fi

save_prop () {
    "$COURSE_BIN"/set_student_property.sh "$@";
}

# Usage: save_student NETID EMAIL CANVAS_ID LAST_COMMA_FIRST
save_student () {
    netid=$1
    email=$2
    canvas_id=$3
    last=${4%%,*}
    first=${4#*,}

    _N save_prop -c $netid email     $email
    _N save_prop    $netid canvas_id $canvas_id
    _N save_prop    $netid last      $last
    _N save_prop    $netid first     $first

    if [ -z "$flag_q" ]; then
        _N print_student_info $netid
    fi
}

json_to_sh () {
    jq -r '
    @sh "save_student \(.login_id) \(.email) \(.id) \(.sortable_name)"
    '
}

eval "$("$@" | json_to_sh)"
