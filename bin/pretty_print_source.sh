#!/bin/sh

# Pretty prints some source code

. "$(dirname "$0")/.CASS"

eval "$(getargs src dst)"

classify_file () {
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
        CMakeLists.txt|*.cmake)
            echo cmake
            ;;
        .*|*.pdf)
            return 1
            ;;
    esac
}

ensure_final_newline () {
    sed '1{}' "$@"
}

markdown_file () {
    local filename
    local filetype
    local marker

    filename=$1; shift
    filetype=$(classify_file "$filename") || return 0

    marker='````'
    while grep -q "^$marker\$" "$filename"; do
        marker='`'$marker
    done

    printf '# `%s`\n\n' "$filename"
    printf '%s {.numberLines .%s}\n' "$marker" "${filetype:-unknown}"
    ensure_final_newline "$filename"
    printf '%s\n\n' "$marker"
}

pp_header () {
    cat <<-····EOF
	---
	title: '$title'
	documentclass: scrartcl
	papersize: letter
	fontsize: 12pt
	geometry:
	- margin=1in
	pagestyle: headings
	numbersections: true
	hyperrefoptions:
	- linktoc=all
	- pdfwindowui
	header-includes:
	- |
	  \usepackage{tocloft}
	  \setlength\cftbeforesecskip{4pt}
	---
	
····EOF
}

pp_tree () {
    pp_header "$1"

    find "$1" \( -name build            \
              -o -name 'cmake-build-*'  \
              -o -name '.?*'            \
              \) -prune                 \
          -o -type f -print |

          tee -a /dev/tty |

    sed 's@^./@@' |

    sort |

    (
        nextpage=
        while read filename; do
            printf "$nextpage"
            markdown_file "$filename"
            # nextpage='\\newpage\n\n'
        done
    )
}

pandoc_options () {
    echo --standalone
    case "$1" in
        *.html)
            echo --to=html5
            echo --css=../css/all.css
            ;;
        *.pdf)
            echo --pdf-engine=xelatex
            echo --toc
            ;;
    esac
}

capture_pdf () {
    set -x
    pandoc $(pandoc_options "$1") -o "$1"
}

case "$dst" in
    [/~]*)
        ;;
    *)
        dst=$(pwd)/$dst
        ;;
esac

title="$(basename "$src" | tr a-z A-Z)"

if [ -d "$src" ]; then
    cd "$src"
    src=.
elif [ -f "$src" ]; then
    cd "$(dirname "$src")"
    src=$(basename "$src")
else
    echo >&2 "$0: Can’t find ‘$1’"
    exit 2
fi

pp_tree "$src" | capture_pdf "$dst"

