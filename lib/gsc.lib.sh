# Fetches from GSC, and caches.

GSC_CACHE=$COURSE_VAR/cache/gsc
mkdir -p "$GSC_CACHE"

# $1: hw
# $2: netid
gsc_partners () {
    local hw; hw=$1; shift
    local netid; netid=$1; shift

    gsc_partners_is_fresh $hw $netid || gsc_partners_refresh $hw

    _gsc_partners_read_cache "$(gsc_partners_cache_path $hw $netid)"
}

# $1: cache
_gsc_partners_read_cache () {
    if ! [ -e "$1" ]; then
        echo DROPPED >"$1"
    fi

    local netid
    for netid in $(cat "$1"); do
        if [ $netid != DROPPED ]; then
            echo $netid
        fi
    done | tr '\n' ' ' | sed 's/ $//'
}

# $1: hw
# $2: netid
gsc_partners_is_fresh () {
    local cache
    cache="$(gsc_partners_cache_path $hw $netid)"

    test -e "$cache" || return

    local age
    age=$(( $(date +%s) - $(stat_mtime_seconds "$cache") ))

    test $age -le "$GSC_PARTNER_CACHE_SECONDS"
}
GSC_PARTNER_CACHE_SECONDS=$(( 24 * 60 ))

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
    cache=$(gsc_partners_cache_path $hw)
    mkdir -p "$cache"

    for netid; do
        echo $* >"${cache}$netid"
    done
}

# $1: hw
# $2: netid (optional)
gsc_partners_cache_path () {
    printf '%s/hw%02d/partners/%s' "$GSC_CACHE" "$1" "${2-}"
}
