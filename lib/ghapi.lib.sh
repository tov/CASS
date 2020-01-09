# Library for accessing GitHub from the shell
# vim: set ts=4 :

course_load_var GITHUB_OAUTH github_oauth.secret

ghapi_curl () {
    eval "$(getargs + verb path ...)"

    if [ -z "$GITHUB_OAUTH" ]; then
        echo >&2 "$0: GITHUB_OAUTH not set"
        exit 1
    fi

    local uri

    case "$path" in
        https://*)
            uri=$path
            ;;
        *)
            uri=https://api.github.com/$path
            ;;
    esac

    curl -s -X "$verb" \
        -H "Authorization: token $GITHUB_OAUTH" \
        -H "Accept: application/vnd.github.baptiste-preview+json" \
        -H "Accept: application/vnd.github.luke-cage-preview+json" \
        -H "Accept: application/vnd.github.hellcat-preview+json" \
        "$@" "$uri"
}

ghapi_uri_repo () {
    eval "$(getargs + repo)"
    echo repos/$github_org/$repo
}

ghapi_uri_branch () {
    eval "$(getargs + repo branch)"
    echo $(ghapi_uri_repo $repo)/branches/$branch
}

ghapi_uri_branch_protection () {
    eval "$(getargs + repo branch)"
    echo $(ghapi_uri_branch $repo $branch)/protection
}

ghapi_uri_org () {
    echo orgs/$github_org
}

ghapi_uri_org_repos () {
    echo "$(ghapi_uri_org)/repos"
}

ghapi_uri_search_org_repos () {
    printf 'search/repositories?q=hw%02d-+in:name+org:%s' $1 $github_org
}

ghapi_repo () {
    eval "$(getargs + verb repo data...)"
    ghapi_curl $verb $(ghapi_uri_repo $repo) --data "$data"
}

ghapi_branch_protection () {
    eval "$(getargs + verb repo branch data...)"
    ghapi_curl $verb $(ghapi_uri_branch_protection $repo $branch) \
        ${data:+--data "$data"}
}

extract_rel_link () {
    eval "$(getargs + type)"
    sed '
        s/^Link: .*<\([^>]*\)>; *rel="'"$type"'".*/\1/
        t found
        d
        :found
    '
}

ghapi_get_all_pages () {
    eval "$(getargs + uri)"

    local headers
    headers=$(mktemp -t ghapi-headers.XXXXXX)

    while [ -n "$uri" ]; do
        ghapi_curl GET "$uri" -D"$headers"
        uri=$(extract_rel_link next <"$headers")
        cat /dev/null > "$headers"
    done
}

ghapi_list_hw_repos () {
    ghapi_get_all_pages $(ghapi_uri_search_org_repos $1)    |
        jq -r '.items[] | .name'                            |
        grep "^hw0*$1-"
}

