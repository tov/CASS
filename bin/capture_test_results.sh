#!/bin/sh

. "$(dirname "$0")/.CASS"
course_use html

capture_test_results "$1"
