#!/bin/sh

if [ -z "$1" -o -z "$2" ]; then
    echo 'Usage: $0 SECONDS CMD...' >&2
    exit 2
fi

seconds=$1; shift
cmdpid=$$

(
    sleep $seconds
    kill $cmdpid
) & exec "$@"
