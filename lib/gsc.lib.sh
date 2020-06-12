# Fetches from GSC, and caches.

GSC_CACHE=$COURSE_VAR/cache/gsc
mkdir -p "$GSC_CACHE"

# $1: hw
# $2: netid
gsc_partners () {
    local hw; hw=$1; shift
    local netid; netid=$1; shift
    local cache

    cache=$(gsc_partners_cache_path $hw)
    test -f "$cache/$netid" || gsc_partners_refresh "$hw"
    cat "$cache/$netid"
}

# $1: hw
gsc_partners_refresh () {
    local hw; hw=$1; shift
    gsc admin submissions hw$hw | while read sub_id netids; do
        if [ -n "$netids" ]; then
            gsc_partners_store $hw $netids
        fi
    done
}

# $1: hw
# $2...: netids
gsc_partners_store () {
    local hw; hw=$1; shift
    local netid
    local cache
    for netid; do
        cache=$(gsc_partners_cache_path $hw)
        mkdir -p "$cache"
        echo $* >"$cache/$netid"
    done
}

# $1: hw
gsc_partners_cache_path () {
    printf '%s/hw%02d/partners' "$GSC_CACHE" "$1"
}
