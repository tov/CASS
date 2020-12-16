# For generating dot graphs

course_use quote

gv_node () {
    local name="$1"
    shift
    gv "$(gv_quote_id "$name")" "$@"
}

gv_edge () {
    local src="$1"
    local dst="$2"
    shift 2
    gv "$(gv_quote_id "$src") -- $(gv_quote_id "$dst")" "$@"
}

gv () {
    printf %s "$1"
    shift
    gv_attrs "$@"
    printf ';\n'
}

gv_attrs () {
    while [ $# != 0 ]; do
        printf ' [%s=%s]' \
            "$(gv_quote_id "${1%%=*}")" \
            "$(gv_quote_id "${1#*=}")"
        shift
    done
}

gv_block () {
    while [ "${1:?gv_block expected ‘--’}" != -- ]; do
        printf '%s ' "$1"
        shift
    done
    shift

    printf '{\n'
    "$@" | sed 's/^/    /'
    printf '}\n'
}

gv_quote_id () {
    if gv_plain_id "$1"; then
        printf %s "$1"
    else
        cdq "$1"
    fi
}

gv_plain_id () {
    return $(printf '%s\n' "$1" | sed -E "$GV_PLAIN_ID_SED")
}

GV_PLAIN_ID_SED='
    2 { s/.*/1/; q; }

    1 {
        /^[_[:alpha:]][_[:alnum:]]*$/ {
            s/.*//; q;
        }

        /^-?[0-9]*([.][0-9]*)?([eE][-+]?[0-9]+)?$/ {
            /^-?[.0-9]/ {
                s/.*//; q;
            }
        }
    }

    s/.*/1/; q;
'
