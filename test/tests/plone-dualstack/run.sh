#!/bin/bash
set -eo pipefail

dir="$(dirname "$(readlink -f "$BASH_SOURCE")")"

image="$1"

PLONE_TEST_SLEEP=3
PLONE_TEST_TRIES=5

cname="plone-container-$RANDOM-$RANDOM"
cid="$(docker run -d --name "$cname" "$image")"
trap "docker rm -vf $cid > /dev/null" EXIT

get() {
	docker exec -i "$cid" /app/bin/python \
		-c "from urllib.request import urlopen; con = urlopen('$1'); print(con.read())"
}

. "$dir/../../retry.sh" --tries "$PLONE_TEST_TRIES" --sleep "$PLONE_TEST_SLEEP" get "http://127.0.0.1:8080"

# Plone answers over IPv4 ...
[[ "$(get 'http://127.0.0.1:8080')" == *"Welcome to Plone!"* ]]
# ... and over IPv6, from within the container's own netns
[[ "$(get 'http://[::1]:8080')" == *"Welcome to Plone!"* ]]
