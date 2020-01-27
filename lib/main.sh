# Common initialization for course admin shell scripts

find_course_root () {
    cd "$(dirname $0)"

    while ! [[ -f .root ]]; do
        if [[ "$(pwd)" = / ]]; then
            echo >&2 Could not find course root
            exit 3
        fi
        cd ..
    done

    pwd
}

load_cass_please () {
    # Find and remember course root
    COURSE_ROOT=$(find_course_root)
    export COURSE_ROOT

    # WARNING: This must not be exported:
    course_cass=$COURSE_ROOT/.CASS
    # WARNING: ^^^ don't export this

    # Load helpful functions
    . "$COURSE_ROOT/.CASS/lib/functions.sh"

    # Initialize the course environment
    course_init_env
}

if [ -z "$course_cass" ]; then
    load_cass_please
fi