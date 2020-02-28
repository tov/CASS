course_use find

info_file=grading-info.txt

# $*: netid...
team_tag () {
    local divider=
    local partner

    for partner; do
        printf %s%s "$divider" $(student_tag $partner)
        divider=_
    done
}

# $1: grading repo directory
team_id () {
    sed '
        /Team ID: */! d
        s///
        q
    ' "$1/$info_file"
}

# $1: hw
grading_base () {
    find_team_repo $1
}

# $1: hw
max_team_id () {
    local dir
    for dir in $(grading_base $1)*; do
        team_id "$dir" 2>/dev/null
    done | sort -nr | head -1
}

# $1: netid
student_tag () {
    {
        print_student_property $1 first
        print_student_property $1 last
    } | sed -E 's/ /-/g; s/[^[:alnum:]]//g'
}

# $1: hw
# $2: netid
# $3: eval item
permalink () {
    printf '%s/grade/%s' "$gsc_base" $(gsc admin permalink hw$1 $2 $3)
}
