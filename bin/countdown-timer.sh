#!/bin/sh

. "$(dirname "$0")/.CASS"

eval "$(getargs duration step)"

width=$(printf %d $duration | wc -c)
(( ++width ))

while (( COLUMNS % width )); do
    (( ++width ))
done

while (( duration > 0 )); do
    if (( duration < step )); then
        step=duration
    fi

    printf >&2 "%-${width}d" $duration
    sleep $step
    duration=$(( duration - step ))
done

echo
