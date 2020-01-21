# TODO

docker_start () {
    local kind; kind=$1; shift
    local name; name=$1; shift
    local hash

    case "$kind" in
        build)
            hash=$(
                docker run \
                    --name "$name" \
                    --rm --read-only --init --detach \
                    --tmpfs /tmp \
                    --volume "$(pwd):/hw:ro" \
                    --volume "$(pwd)/build:/hw/build:rw" \
                    --workdir /hw \
                    ubuntu-gcc \
                    sh -c 'sleep 600'
            ) || return 1
            trap "docker kill $hash 1>/dev/null" EXIT
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
                    --workdir /hw/build \
                    ubuntu-gcc \
                    sh -c 'sleep 300'
            ) || return 1
            trap "docker kill $hash 1>/dev/null" EXIT
            CURRENT_TEST_CONTAINER=$hash
            export CURRENT_TEST_CONTAINER
            ;;
        *)
            echo >&2 "docker_start: unknown kind: $kind"
            return 1
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
            echo >&2 "get_current_container_var: unknown kind: $1"
            return 1
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
        echo >&2 "get_current_container: $varname not set"
        return 1
    fi
}

docker_build () {
    local hash
    hash=$(get_current_container build) || return 1
    docker exec $hash "$@"
}

docker_test () {
    local hash
    hash=$(get_current_container test) || return 1
    gtimeout $COURSE_GRADE_TIMEOUT \
        docker exec --interactive $hash "$@"
}

docker_execute () {
    local command; command=$1; shift
    local exitcode; exitcode=$1; shift

    case "$command" in
        =*)
            command=${command#=}
            ;;
        *)
            command=./$command
            ;;
    esac

    if docker_test ./capture_output.sh $COURSE_MAX_OUTPUT $command; then
        echo 0 >| "$exitcode"
    else
        echo $? >| "$exitcode"
    fi
}

