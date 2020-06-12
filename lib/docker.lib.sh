# Start, use, and stop docker.

docker_time_limit=600

docker_lib_on_exit () {
    for hash in $docker_kill_on_exit_list; do
        docker kill $hash >/dev/null
    done
}

register_exit_function docker_lib_on_exit

docker_kill_on_exit () {
    set -- ${docker_kill_on_exit_list-} $*
    docker_kill_on_exit_list=$*
}

try_docker_start () {
    local kind; kind=$1; shift
    local name; name=$1; shift
    local image; image=cs211-$kind
    export CURRENT_CONTAINER; CURRENT_CONTAINER=

    case "$kind" in
        build)
            CURRENT_CONTAINER=$(
                docker run \
                    --name "$name" \
                    --rm --read-only --init --detach \
                    --tmpfs /tmp \
                    --volume "$(pwd):/hw:rw" \
                    --workdir /hw \
                    "$@" \
                    $image \
                    sleep $docker_time_limit
            ) || return 1
            CURRENT_BUILD_CONTAINER=$CURRENT_CONTAINER
            export CURRENT_BUILD_CONTAINER
            ;;
        test)
            local workdir
            if [ -d build ]; then
                workdir=/hw/build
            else
                workdir=/hw
            fi
            mkdir -p out
            CURRENT_CONTAINER=$(
                docker run \
                    --name "$name" \
                    --rm --read-only --init --detach \
                    --tmpfs /tmp \
                    --volume "$(pwd):/hw:ro" \
                    --volume "$(pwd)/out:/out:rw" \
                    --workdir "$workdir" \
                    "$@" \
                    $image \
                    sleep $docker_time_limit
            ) || return 1
            CURRENT_TEST_CONTAINER=$CURRENT_CONTAINER
            export CURRENT_TEST_CONTAINER
            ;;
        *)
            cass_error 12 "docker_start: unknown kind: $kind" || return
            ;;
    esac
}

docker_start () {
    local attempts; attempts=${DOCKER_START_ATTEMPTS:-5}
    local attempt_number
    for attempt_number in $(seq $attempts); do
        if try_docker_start "$@"; then
            if [ -z "$NO_DOCKER_REAP" ]; then
                docker_kill_on_exit "$CURRENT_CONTAINER"
            fi
            return 0
        fi

        {
            echo "Warning: Couldn't start docker"
            docker ps -a
            echo "Sleeping $attempt_number seconds..."
            sleep $attempt_number
            echo "Trying again..."
        } >&2
    done 2>&4

    cass_error 99 "Couldn't start docker after $attempts tries"
}

_container_for_fmt=hw%02d-%s-%s
get_container_for () {
    container=$(printf $_container_for_fmt "$1" "$2" "$3")
    CURRENT_CONTAINER=$(docker ps --no-trunc -qf name=$container)
    if [ -n "$CURRENT_CONTAINER" ]; then
        echo "$CURRENT_CONTAINER"
    else
        docker ps -a >&4
        cass_fatal 104 "need to start me a container"
    fi
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

