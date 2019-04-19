#!/bin/sh

. "$(dirname "$0")/../lib/common.sh"

eval "$(getargs new_name project_dir)"

cd "$project_dir"

old_name="$(sed '/^project(/!d; s/project( *//; s/ .*//' CMakeLists.txt)"

if [ -z "$old_name" ]; then
    echo>&2 Error: could not find old name
    exit 3
fi

find . -type f -name "*${old_name}*" | while read before; do
    after="$(echo "$before" | sed "s@${old_name}@${new_name}@")"
    if [ "$before" != "$after" ]; then
        mv "$before" "$after"
    fi
done

find . -type f -exec perl -pi -e "s@\\b${old_name}\\b@${new_name}@g" '{}' ';'

