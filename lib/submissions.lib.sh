course_use find

info_file=grading-info.txt

# $1: property heading
# $2...: grading repo directories
get_repo_prop () {
    local prop; prop=$1; shift
    local repo
    for repo; do
        sed "
            /^$prop: */! d
            s///
            q
        " "$repo/$info_file"
    done
}

# $1: property heading
# $2: new property value
# $3...: grading repo directories
set_repo_prop () {
    local prop; prop=$1; shift
    local valu; valu=$1; shift
    local repo
    for repo; do
        sed -i.bak "s/^\\($prop\\):.*/\\1: $valu/" "$repo/$info_file"
    done
}

# $1: grading repo directory
repo_team_id () {
    get_repo_prop 'Team ID' "$@"
}

# $1: grading repo directory
repo_grader () {
    get_repo_prop 'Grader' "$@"
}

# $1: hw
# $2: netid
netid_team () {
    gsc admin partners hw$1 $2
}

# $*: netid...
team_tag () {
    local divider=
    local partner

    for partner; do
        printf %s%s "$divider" $(student_tag_ $partner)
        divider=_
    done
}

# $1: netid
student_tag_ () {
    {
        print_student_property $1 first
        print_student_property $1 last
    } | sed -E 's/ /-/g; s/[^[:alnum:]]//g'
}

# $1: hw
grading_base () {
    find_team_repo $1
}

# $1: hw
max_team_id () {
    local dir
    for dir in $(grading_base $1)*; do
        repo_team_id "$dir" 2>/dev/null
    done | sort -nr | head -1
}

# $1: hw
# $2: netid
# $3: eval item
permalink () {
    printf '%s/grade/%s' "$gsc_base" $(gsc admin permalink hw$1 $2 $3)
}
