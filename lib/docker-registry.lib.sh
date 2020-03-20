# Docker registry API

course_load_var gscauth gscauth.secret
DOCKER_REGISTRY_AUTH=$(echo "$gscauth" | sed 's/:.*=/:/')
gscauth=

docker_registry_api=https://$docker_registry/v2

dr_curl () {
    eval "$(getargs + verb path ...)"

    if [ -z "$DOCKER_REGISTRY_AUTH" ]; then
        echo >&2 "$0: DOCKER_REGISTRY_AUTH not set"
        return 1
    fi

    local uri

    case "$path" in
        https://*)
            uri=$path
            ;;
        *)
            uri=$docker_registry_api/$path
            ;;
    esac

    curl -s -X "$verb" \
        -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
        -u "$DOCKER_REGISTRY_AUTH" \
        "$@" "$uri"
}

dr_image_get_digest () {
    dr_curl GET "$1/manifests/${2:-latest}" | jq -r .config.digest
}

dr_delete_image () {
    dr_curl DELETE "$1/manifests/$(dr_image_get_digest "$@")"
}

