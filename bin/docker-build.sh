#!/bin/sh

. "$(dirname "$0")/.CASS"
course_use find docker

eval "$(getargs hw ...)"

container=$(format_homework $hw)-$(basename "$(pwd)")-build
docker_start_if_not build $container
docker_build "$@"
