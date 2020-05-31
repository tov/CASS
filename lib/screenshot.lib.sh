# Taking screenshots of student programs

check_bin () {
    if [ -x build/"$1" ]; then
        true
    else
        html_errorhead 'Warning!'
        html_p "Skipping <code class='filename'>$1</code>" \
               "(no executable present)."
        false
    fi
}

screenshot_program () {
    check_bin $1 || return 0

    trap COURSE_GRADE_TIMEOUT=$COURSE_GRADE_TIMEOUT RETURN
    COURSE_GRADE_TIMEOUT=15

    png=$1-screenshot.png
    program_test $1 \
        -m="Trying to start your <code class='filename'>$1</code>." \
        -x "/usr/local/bin/x_test.sh /hw/build/$1 /out/$png" \
        -c 0
}

