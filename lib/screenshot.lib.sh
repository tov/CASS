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

    pulseaudio --start >/dev/null 2>&1 || true

    png=$1-screenshot.png
    points=0

    HTML_DETAILS_OPEN=1 program_test $1 \
        -m="Trying to start your <code class='filename'>$1</code>." \
        -x "/usr/local/bin/x_test.sh /hw/build/$1 /out/$png" \
        -c 0
    unset HTML_DETAILS_OPEN

    if [ -f "out/$png" ]; then
        url=/gsc/files/$TEST_NETID/$TEST_HW/$png
        html_p Here’s your screenshot:
        printf '<p class="screenshot">'
        printf '<a href="%s" target="_blank">' "$url"
        printf '<img src="%s" alt="Screenshot of %s"/>' "$url" "$1"
        printf '</a>'
        printf '</p>\n'
    fi
}

