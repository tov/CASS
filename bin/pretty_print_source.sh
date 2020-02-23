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

find_source_files () {
    find "$1" \( -name build            \
              -o -name 'cmake-build-*'  \
              -o -name '.?*'            \
              \) -prune                 \
          -o -type f -print             |

    sed 's@^./@@'                       |

    ruby -e '
        def is_header_for(a, b)
            a =~ /^(.*[.])h([^.]*)$/ and
                $1 + "c" + $2 == b
        end

        lines = $stdin.readlines

        lines.sort! do |a, b|
            if is_header_for(a, b)
                -1
            elsif is_header_for(b, a)
                1
            else
                a.downcase <=> b.downcase
            end
        end

        for line in lines
            line.sub!(/^[.]\//, "")
            print(line)
        end
    '
}

pp_tree () (
    cd "$1"

    pp_header "$2"

    find_source_files "$2"      |
    tee -a /dev/tty             |
    while read filename; do
        markdown_file "$filename"
    done
)

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
        *.tex)
            echo --toc
            ;;
    esac
}

capture_pdf () {
    pandoc $(pandoc_options "$1") -o "$1"
}

title="$(basename "$src" | tr a-z A-Z)"

if [ -d "$src" ]; then
    dir=$src
    src=.
elif [ -f "$src" ]; then
    dir=$(dirname "$src")
    src=$(basename "$src")
else
    echo >&2 "$0: Can’t find ‘$1’"
    exit 2
fi

pp_tree "$dir" "$src" | capture_pdf "$dst"

