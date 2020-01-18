# Common initialization for course admin shell scripts

# Exit on errors, including errors in piped subshells
set -eo pipefail

# Load helpful functions
. "$(dirname $0)/../lib/functions.sh"

# Initialize the course environment
course_init_env
