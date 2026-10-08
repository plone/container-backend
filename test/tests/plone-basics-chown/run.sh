#!/bin/bash
set -eo pipefail

image="$1"

# Case 1: /data owned by root. Should fix it automatically.
echo "--- Case 1: Automatic fix ---"
cname1="plone-chown-auto-$RANDOM"
docker run --name "$cname1" -v /data busybox sh -c "chown root:root /data && touch /data/auto"
docker run --rm --volumes-from "$cname1" "$image" true
docker run --rm --volumes-from "$cname1" busybox stat -c "%u:%g" /data/auto | grep -q "500:500"
docker rm -v "$cname1" > /dev/null

# Case 2: /data owned by plone, but FORCE_CHOWN=1. Should fix it manually.
echo "--- Case 2: Forced fix ---"
cname2="plone-chown-force-$RANDOM"
docker run --name "$cname2" -v /data busybox sh -c "chown 500:500 /data && touch /data/forced && chown root:root /data/forced"
docker run --rm --volumes-from "$cname2" -e FORCE_CHOWN="1" "$image" true
docker run --rm --volumes-from "$cname2" busybox stat -c "%u:%g" /data/forced | grep -q "500:500"
docker rm -v "$cname2" > /dev/null

# Case 3: /data owned by plone, no FORCE_CHOWN. Should NOT fix (no message).
echo "--- Case 3: No fix ---"
cname3="plone-chown-none-$RANDOM"
docker run --name "$cname3" -v /data busybox sh -c "chown 500:500 /data && touch /data/no-fix && chown root:root /data/no-fix"
docker run --rm --volumes-from "$cname3" "$image" true
# Should still be root:root (0:0)
docker run --rm --volumes-from "$cname3" busybox stat -c "%u:%g" /data/no-fix | grep -q "0:0"
docker rm -v "$cname3" > /dev/null
