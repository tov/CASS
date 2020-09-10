# Library for accessing GitHub from the shell
# vim: set ts=4 :

course_load_var GITHUB_OAUTH github_oauth.secret

course_use apicommon

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
    echo repos/$github_org/$1
}

ghapi_uri_branch () {
    echo repos/$github_org/$1/branches/$2
}

ghapi_uri_branch_protection () {
    echo repos/$github_org/$1/branches/$2/protection
}

ghapi_uri_org () {
    echo orgs/$github_org
}

ghapi_uri_org_repos () {
    echo "orgs/$github_org/repos"
}

ghapi_uri_search_org_repos () {
    printf 'search/repositories?q=hw%02d-+in:name+org:%s' $1 $github_org
}

ghapi_repo () {
    eval "$(getargs + verb repo data...)"
    ghapi_curl $verb $(ghapi_uri_repo $repo) --data "$data"
}

ghapi_create_repo () {
    eval "$(getargs + repo data...)"
    local json
    json=$(jq -cnM "{ name: \"$repo\", $data }")
    ghapi_curl POST "orgs/$github_org/repos" --data "$json"
}

ghapi_branch_protection () {
    eval "$(getargs + verb repo branch data...)"
    ghapi_curl $verb $(ghapi_uri_branch_protection $repo $branch) \
        ${data:+--data "$data"}
}

ghapi_get_all_pages () {
    get_all_pages 'ghapi_curl GET' "$1"
}

ghapi_list_hw_repos () {
    ghapi_get_all_pages $(ghapi_uri_search_org_repos $1)    |
        jq -r '.items[] | .name'                            |
        grep "^hw0*$1-"
}

