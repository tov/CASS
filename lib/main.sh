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
    cass_is_loaded=1

    # Find and remember course root
    COURSE_ROOT=$(find_course_root)
    export COURSE_ROOT

    # Load helpful functions
    . "$COURSE_ROOT/.CASS/lib/functions.sh"

    # Initialize the course environment
    course_init_env
}

if [ -z "$cass_is_loaded" ]; then
    load_cass_please
fi
