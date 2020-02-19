format_homework () {
    printf "hw%02d\n" "$1"
}

find_team_repo () {
    local maybe_dot; maybe_dot=

    case "$2" in
        starter|solution) maybe_dot=.
    esac

    echo "$COURSE_VAR/grading/$(format_homework "$1")/$maybe_dot$2"
}

find_existing_file () {
    local file

    for file; do
        if [ -f "$file" ]; then
            echo $file
            return
        fi
    done
}

find_homework_base () {
    printf "%s/dev/hw/%02d\n" "$COURSE_ROOT" "$1"
}

find_homework_test_repo () {
    printf "%s/dev/hw/test/%s-hw%02d\n" "$COURSE_ROOT" "$2" "$1"
}

find_grading_script () {
    local hw; hw=$(format_homework "$1")
    find_existing_file \
        "$COURSE_LIB/grading/$hw/grade_this" \
        "$COURSE_LIB/grading/grade_this_$hw"
}

find_preparation_script () {
    local hw; hw=$(format_homework "$1")
    find_existing_file \
        "$COURSE_LIB/grading/$hw/prepare_this" \
        "$COURSE_LIB/grading/prepare_this_$hw"
}
