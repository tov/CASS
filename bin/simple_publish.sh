#!/bin/sh

. "$(dirname "$0")/.CASS"

eval "$(getargs src dst)"

publish_dir "$src" "$dst"
