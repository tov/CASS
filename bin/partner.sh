#!/bin/sh

# -v     make gsc verbose
# -q     only print partner NetID
# -s     silence error messages
# -E     no error if no partner exists
# -N     dry run
# -R     don't re-resolve student names

set -eu

. "$(dirname "$0")/.CASS"
course_use dry_run

eval "$(getargs -vqsENR hw netid1 netid2=)"
dry_run_if [ -n "$flag_N" ]

main () {
    netid1=$(resolve_student $flag_R "$netid1")
    if [ -n "$netid2" ]; then
        netid2=$(resolve_student $flag_R "$netid2")
        assign_partners
    else
        print_partnership
    fi
}

assign_partners () {
    _N gsc $flag_v -u $netid1 partner request hw$hw $netid2
    _N gsc $flag_v -u $netid2 partner request hw$hw $netid1
}

print_partnership () {
    if ! partners=$(gsc admin partners hw$hw $netid1 | tr ' ' '\n')
    then
        ${flag_s:+:} echo>&2 "no partner info found for $netid1 hw$hw"
        exit 1
    fi

    if ! netid2=$(echo "$partners" | grep -v "^${netid1}\$") &&
        [ -z "$flag_E" ]
    then
        ${flag_s:+:} echo>&2 "$netid1 has no partner for hw$hw"
        exit 2
    fi

    if [ -n "$flag_q" ]; then
        if [ -n "$netid2" ]; then
            echo $netid2
        fi
    else
        for netid in $partners; do
            print_student_info -n "$netid"
        done
    fi
}

####
main
####
