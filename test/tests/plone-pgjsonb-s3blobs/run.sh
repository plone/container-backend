#!/bin/bash
set -eo pipefail

dir="$(dirname "$(readlink -f "$BASH_SOURCE")")"

image="$1"

PLONE_TEST_SLEEP=10
PLONE_TEST_TRIES=10

DSN="dbname='plone' user='plone' host='db' password='plone'"
S3_ACCESS_KEY="access-$RANDOM-$RANDOM"
S3_SECRET_KEY="s3cr3t-$RANDOM-$RANDOM"
S3_BUCKET="plone"

# Enabling S3 blobs with missing settings must fail without printing credentials
if out="$(docker run --rm \
	-e ZODB_PGJSONB_DSN="$DSN" \
	-e ZODB_PGJSONB_S3BLOBS_ENABLED=true \
	-e ZODB_PGJSONB_S3BLOBS_ENDPOINT_URL="http://s3:5000" \
	-e ZODB_PGJSONB_S3BLOBS_ACCESS_KEY="$S3_ACCESS_KEY" \
	-e ZODB_PGJSONB_S3BLOBS_SECRET_KEY="$S3_SECRET_KEY" \
	"$image" true 2>&1)"; then
	echo >&2 "container started although the S3 bucket name is missing"
	false
fi
[[ "$out" == *"Bucket: MISSING"* ]]
[[ "$out" == *"Secret Key: set"* ]]
[[ "$out" != *"$S3_SECRET_KEY"* ]]
[[ "$out" != *"$S3_ACCESS_KEY"* ]]

# Start Postgres
zname="pgjsonb-container-$RANDOM-$RANDOM"
zpull="$(docker pull postgres:17)"
zid="$(docker run -d --name "$zname" -e POSTGRES_USER=plone -e POSTGRES_PASSWORD=plone -e POSTGRES_DB=plone postgres:17)"

# Start an S3-compatible server
sname="s3-container-$RANDOM-$RANDOM"
spull="$(docker pull motoserver/moto:5.2.3)"
sid="$(docker run -d --name "$sname" motoserver/moto:5.2.3)"

pname="plone-container-$RANDOM-$RANDOM"

# Tear down
trap "docker rm -vf $sid $zid > /dev/null; docker rm -vf $pname > /dev/null 2>&1 || true" EXIT

s3() {
	docker run --rm -i \
		--link "$sname":s3 \
		--entrypoint /app/bin/python \
		"$image" \
		-c "import boto3; s3 = boto3.client('s3', endpoint_url='http://s3:5000', region_name='us-east-1', aws_access_key_id='$S3_ACCESS_KEY', aws_secret_access_key='$S3_SECRET_KEY'); $1"
}

# Create the bucket once the S3 server accepts connections
. "$dir/../../retry.sh" --tries "$PLONE_TEST_TRIES" --sleep 2 s3 "\"s3.create_bucket(Bucket='$S3_BUCKET')\""

plone_env=(
	-e ZODB_PGJSONB_DSN="$DSN"
	-e ZODB_PGJSONB_S3BLOBS_ENABLED=true
	-e ZODB_PGJSONB_S3BLOBS_ENDPOINT_URL="http://s3:5000"
	-e ZODB_PGJSONB_S3BLOBS_BUCKET_NAME="$S3_BUCKET"
	-e ZODB_PGJSONB_S3BLOBS_ACCESS_KEY="$S3_ACCESS_KEY"
	-e ZODB_PGJSONB_S3BLOBS_SECRET_KEY="$S3_SECRET_KEY"
)

# Start Plone as zodb-pgjsonb client with blobs in S3
pid="$(docker run -d --name "$pname" --link=$zname:db --link=$sname:s3 "${plone_env[@]}" "$image")"

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

# The zodb-pgjsonb S3 blobs configuration was used
[[ "$(docker logs "$pid" 2>&1)" == *"Using zodb-pgjsonb S3 blobs configuration"* ]]

# A blob above the size threshold ends up in the bucket
docker run --rm --link=$zname:db --link=$sname:s3 "${plone_env[@]}" \
	-v "$dir/write_blob.py:/app/write_blob.py:ro" \
	"$image" run /app/write_blob.py | grep -q "blob committed"
[[ "$(s3 "print(s3.list_objects_v2(Bucket='$S3_BUCKET').get('KeyCount', 0))")" -ge 1 ]]
