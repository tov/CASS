#!/bin/sh

# Pretty prints some source code

. "$(dirname "$0")/.CASS"

classify_filetype () {
    case "$1" in
        *.c|*.h)
            echo c
            ;;
        *.C|*.cxx|*.cpp|*.c++|*.cc|*.H|*.hxx|*.hpp|*.h++|*.hh)
            echo cpp
            ;;
        *.py)
            echo python
            ;;
        *.sh)
            echo sh
            ;;
        Makefile)
            echo makefile
            ;;
        .*|*.pdf)
            return 1
            ;;
    esac
}

pp_file () {
    local filename; filename=$1; shift
    local filetype; filetype=$(classify_filetype "$filename") || return 0
    local flag_E

    if [ -n "$filetype" ]; then
        flag_E=-E$filetype
    else
        flag_E=
    fi

    enscript -o- -MLetter --color $flag_E "$filename"
}

pp_tree () {
    find "$1" -name build -prune \
           -o -type f -print |

    sed 's@^./@@' |

    sort |

    while read filename; do
        pp_file "$filename"
    done |

    ps2pdf - "$2"
}

case "$2" in
    [/~]*)
        dst=$2
        ;;
    *)
        dst=$(pwd)/$2
        ;;
esac

if [ -d "$1" ]; then
    cd "$1"
    src=.
elif [ -f "$1" ]; then
    cd "$(dirname "$1")"
    src=$(basename "$1")
else
    echo >&2 "$0: Can’t find ‘$1’"
    exit 2
fi

pp_tree "$src" "$dst"

