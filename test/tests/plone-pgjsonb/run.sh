#!/bin/bash
set -eo pipefail

dir="$(dirname "$(readlink -f "$BASH_SOURCE")")"

image="$1"

PLONE_TEST_SLEEP=10
PLONE_TEST_TRIES=10

# Start Postgres
zname="pgjsonb-container-$RANDOM-$RANDOM"
zpull="$(docker pull postgres:17)"
zid="$(docker run -d --name "$zname" -e POSTGRES_USER=plone -e POSTGRES_PASSWORD=plone -e POSTGRES_DB=plone postgres:17)"

# Start Plone as zodb-pgjsonb client
pname="plone-container-$RANDOM-$RANDOM"
pid="$(docker run -d --name "$pname" --link=$zname:db -e ZODB_PGJSONB_DSN="dbname='plone' user='plone' host='db' password='plone'" "$image")"

# Tear down
trap "docker rm -vf $pid $zid > /dev/null" EXIT

get() {
	docker run --rm -i \
		--link "$pname":plone \
		--entrypoint /app/bin/python \
		"$image" \
		-c "from urllib.request import urlopen; con = urlopen('$1'); print(con.read())"
}

. "$dir/../../retry.sh" --tries "$PLONE_TEST_TRIES" --sleep "$PLONE_TEST_SLEEP" get "http://plone:8080"

# Plone is up and running
[[ "$(get 'http://plone:8080')" == *"Welcome to Plone!"* ]]

# The zodb-pgjsonb configuration was used
[[ "$(docker logs "$pid" 2>&1)" == *"Using zodb-pgjsonb configuration"* ]]
