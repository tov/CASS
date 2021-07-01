# Library for cleaning up compiler output to make it more readable.

c_redact () {
    {
        "$@" |
        ubsed -E '
            /^make\[[0-9]+\]: (Entering|Leaving) directory /d
            /^ln /d
            s| +-f[^ ]*||g
            s| +-[DI][^ ]*| ${CPPFLAGS}|
            s| +-[Ll][^ ]*| ${LDFLAGS}|
            s| +-[gpsW][^ ]*| ${CFLAGS}|
            s| +@[^ ]+||g
            s| +-[^co][^ ]*||g
        '
    } 2>&1 | ubsed -E '
        s|build[.]em/||g
        s|/usr/local/emsdk/upstream/emscripten/||g
        s|/usr/local/asmjs-unknown-emscripten/|$EM_PREFIX/|g
        s|[$]EM_PREFIX/src/dot-cs211/lib/ge211|${GE211_DIR}/|g
        s|[$]EM_PREFIX/|${EM_PREFIX}/|g
        s|[^ ]*[.]tester|${TEST_DIR}|g
        s|tester|${MY_TESTS}|g
        s|docker exec .* cc |${CC} |g
        s|docker exec .* c[+][+] |${CXX} |g
        s|//+|/|g
    '
}

c_expand () {
    sed '
        s|^/hw/||
        s|[$]{TEST_DIR}|.tester|g
        s|[$]{MY_TESTS}|tester|g
    ' "$1"
}

cxx_redact () {
    c_redact "$@"
}

cxx_expand () {
    c_expand "$@"
}

dssl2_redact () {
    "$@" | ubsed -E '
               /^make\[[0-9]+\]: (Entering|Leaving) directory /d
               s@ [0-9]>&[0-9]@@
               s@/home/tov/cs214/var/grading[^/]*/@@
               s@[.]tester@${TEST_DIR}@g
           '
}

dssl2_expand () {
    cat "$1"
}

