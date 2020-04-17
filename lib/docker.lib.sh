# Start, use, and stop docker.

docker_time_limit=600

docker_lib_on_exit () {
    for hash in $docker_kill_on_exit_list; do
        docker kill $hash >/dev/null
    done
}

register_exit_function docker_lib_on_exit

docker_kill_on_exit () {
    set -- $docker_kill_on_exit_list $*
    docker_kill_on_exit_list=$*
}

docker_start () {
    local kind; kind=$1; shift
    local name; name=$1; shift
    local image; image=cs211-$kind
    local hash

    case "$kind" in
        build)
            hash=$(
                docker run \
                    --name "$name" \
                    --rm --read-only --init --detach \
                    --tmpfs /tmp \
                    --volume "$(pwd):/hw:rw" \
                    --workdir /hw \
                    "$@" \
                    $image \
                    sleep $docker_time_limit
            ) || cass_error 10
            docker_kill_on_exit $hash
            CURRENT_BUILD_CONTAINER=$hash
            export CURRENT_BUILD_CONTAINER
            ;;
        test)
            hash=$(
                docker run \
                    --name "$name" \
                    --rm --read-only --init --detach \
                    --tmpfs /tmp \
                    --volume "$(pwd):/hw:ro" \
                    --volume "$(pwd)/out:/out:rw" \
                    --workdir "/hw$(! test -d build || echo /build)" \
                    "$@" \
                    $image \
                    sleep $docker_time_limit
            ) || cass_error 11
            docker_kill_on_exit $hash
            CURRENT_TEST_CONTAINER=$hash
            export CURRENT_TEST_CONTAINER
            ;;
        *)
            cass_error 12 "docker_start: unknown kind: $kind" || return
            ;;
    esac
}

get_current_container_var () {
    case "$1" in
        build)
            echo CURRENT_BUILD_CONTAINER
            ;;
        test)
            echo CURRENT_TEST_CONTAINER
            ;;
        *)
            cass_error 13 "get_current_container_var: unknown kind: $1" ||
                return
            ;;
    esac
}

get_current_container () {
    local hash

    varname=$(get_current_container_var "$1")
    eval "hash=\$$varname"

    if [ -n "$hash" ]; then
        echo $hash
    else
        cass_error 14 "get_current_container: $varname not set" || return
    fi
}

docker_build () {
    local hash
    hash=$(get_current_container build) || return
    docker exec $hash "$@"
}

docker_test () {
    local hash
    hash=$(get_current_container test) || return

    local outer_runner
    outer_runner="gtimeout $COURSE_GRADE_TIMEOUT"

    local inner_runner
    inner_runner="capture_output.sh $COURSE_MAX_OUTPUT"

    case "$1" in
        -I*)
            inner_runner=${1#-I}
            shift
            ;;
        *)
            ;;
    esac

    local command; command=$1; shift
    local exitcodefile; exitcodefile=$1; shift

    case "$command" in
        [/.~]*)
            command=$command
            ;;
        *)
            command=./$command
            ;;
    esac

    if $outer_runner \
        docker exec --interactive "$@" $hash \
        $inner_runner $command
    then
        echo 0 >|"$exitcodefile"
    else
        echo $? >|"$exitcodefile"
    fi
}

