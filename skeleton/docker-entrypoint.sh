#!/bin/bash
set -e
export VENVBIN=/app/bin

if [ -z "${PIP_PARAMS}" ]; then
  PIP_PARAMS=""
fi

if [ -z "${CLIENT_HOME}" ]; then
  CLIENT_HOME="/data/$(hostname)/$(hostid)"
  export CLIENT_HOME=$CLIENT_HOME
fi

USER="$(id -u)"

# Create directories to be used by Plone
mkdir -p /data/filestorage /data/blobstorage /data/cache /data/log $CLIENT_HOME
if [ "$USER" = '0' ]; then
  # Check ownership, OR check if we are explicitly forcing a fix
  if [ "$(stat -c '%U' /data)" != "plone" ] || [ "$FORCE_CHOWN" = "1" ]; then
    echo "Running chown to fix ownership of the data directory"
    find /data -not -user plone -exec chown plone:plone {} \+
  fi
  sudo="gosu plone"
else
  sudo=""
fi

# MAIN ENV Vars
[ -z ${SECURITY_POLICY_IMPLEMENTATION+x} ] && export SECURITY_POLICY_IMPLEMENTATION=C
[ -z ${VERBOSE_SECURITY+x} ] && export VERBOSE_SECURITY=off
[ -z ${DEFAULT_ZPUBLISHER_ENCODING+x} ] && export DEFAULT_ZPUBLISHER_ENCODING=utf-8
[ -z ${COMPILE_MO_FILES+x} ] && export COMPILE_MO_FILES=true
[ -z ${DEBUG_MODE+x} ] && export DEBUG_MODE=off
[ -z ${ZOPE_FORM_MEMORY_LIMIT+x} ] && export ZOPE_FORM_MEMORY_LIMIT=4MB
[ -z ${ZOPE_FORM_DISK_LIMIT+x} ] && export ZOPE_FORM_DISK_LIMIT=1GB
[ -z ${ZOPE_FORM_MEMFILE_LIMIT+x} ] && export ZOPE_FORM_MEMFILE_LIMIT=4KB


# ZODB ENV Vars
[ -z ${ZODB_CACHE_SIZE+x} ] && export ZODB_CACHE_SIZE=50000

if [[ -v RELSTORAGE_DSN ]]; then
  MSG="Using Relstorage configuration"
  CONF=relstorage.conf
  # Relstorage ENV Vars
  [ -z ${RELSTORAGE_NAME+x} ] && export RELSTORAGE_NAME=storage
  [ -z ${RELSTORAGE_READ_ONLY+x} ] && export RELSTORAGE_READ_ONLY=off
  [ -z ${RELSTORAGE_KEEP_HISTORY+x} ] && export RELSTORAGE_KEEP_HISTORY=true
  [ -z ${RELSTORAGE_COMMIT_LOCK_TIMEOUT+x} ] && export RELSTORAGE_COMMIT_LOCK_TIMEOUT=30
  [ -z ${RELSTORAGE_CREATE_SCHEMA+x} ] && export RELSTORAGE_CREATE_SCHEMA=true
  [ -z ${RELSTORAGE_SHARED_BLOB_DIR+x} ] && export RELSTORAGE_SHARED_BLOB_DIR=false
  [ -z ${RELSTORAGE_BLOB_CACHE_SIZE+x} ] && export RELSTORAGE_BLOB_CACHE_SIZE=100mb
  [ -z ${RELSTORAGE_BLOB_CACHE_SIZE_CHECK+x} ] && export RELSTORAGE_BLOB_CACHE_SIZE_CHECK=10
  [ -z ${RELSTORAGE_BLOB_CACHE_SIZE_CHECK_EXTERNAL+x} ] && export RELSTORAGE_BLOB_CACHE_SIZE_CHECK_EXTERNAL=false
  [ -z ${RELSTORAGE_BLOB_CHUNK_SIZE+x} ] && export RELSTORAGE_BLOB_CHUNK_SIZE=1048576
  [ -z ${RELSTORAGE_CACHE_LOCAL_MB+x} ] && export RELSTORAGE_CACHE_LOCAL_MB=10
  [ -z ${RELSTORAGE_CACHE_LOCAL_OBJECT_MAX+x} ] && export RELSTORAGE_CACHE_LOCAL_OBJECT_MAX=16384
  [ -z ${RELSTORAGE_CACHE_LOCAL_COMPRESSION+x} ] && export RELSTORAGE_CACHE_LOCAL_COMPRESSION=none
  [ -z ${RELSTORAGE_CACHE_DELTA_SIZE_LIMIT+x} ] && export RELSTORAGE_CACHE_DELTA_SIZE_LIMIT=100000
elif  [[ -v ZEO_ADDRESS ]]; then
  MSG="Using ZEO configuration"
  CONF=zeo.conf
  # Check ZEO variables
  [ -z ${ZEO_SHARED_BLOB_DIR+x} ] && export ZEO_SHARED_BLOB_DIR=off
  [ -z ${ZEO_READ_ONLY+x} ] && export ZEO_READ_ONLY=false
  [ -z ${ZEO_CLIENT_READ_ONLY_FALLBACK+x} ] && export ZEO_CLIENT_READ_ONLY_FALLBACK=false
  [ -z ${ZEO_STORAGE+x} ] && export ZEO_STORAGE=1
  [ -z ${ZEO_CLIENT_CACHE_SIZE+x} ] && export ZEO_CLIENT_CACHE_SIZE=128MB
  [ -z ${ZEO_DROP_CACHE_RATHER_VERIFY+x} ] && export ZEO_DROP_CACHE_RATHER_VERIFY=false
else
  MSG="Using default configuration"
  CONF=zope.conf
fi

# Add anything inside etc/zope.conf.d to the configuration file
# prior to starting the respective Zope server.
# This provides a counterpart for the ZCML package-includes
# functionality, but for Zope configuration snippets.
#
# This must be executed only once during the container lifetime,
# as container can be stopped and then restarted... double-additions
# of the same snippet cause the Zope server not to start.
if grep -q '# Runtime customizations:' etc/${CONF} ; then
  # Note in the log this was customized.  Useful for bug reports.
  MSG="${MSG} -- with customizations"
else
  # Assume there will be no customizations.
  zope_conf_vanilla=true
  for f in etc/zope.conf.d/*.conf ; do
    test -f ${f} || continue
    # Oh, it looks like there is at least one customization.
    if [[ -v zope_conf_vanilla ]] ; then
      # Make a note both in the file and in the log.
      echo >> etc/${CONF}
      echo "# Runtime customizations:" >> etc/${CONF}
      MSG="${MSG} -- with customizations"
      # We don't need to rerun the same snippet twice here.
      unset zope_conf_vanilla
    fi
    echo >> etc/${CONF}
    cat ${f} >> etc/${CONF}
  done
fi

# Handle CORS
$sudo $VENVBIN/python /app/scripts/cors.py

# Handle ADDONS installation
if [[ -n "${ADDONS}" ]]; then
  echo "======================================================================================="
  echo "Installing ADDONS ${ADDONS}"
  echo "THIS IS NOT MEANT TO BE USED IN PRODUCTION"
  echo "Read about it: https://6.docs.plone.org/install/containers/images/backend.html"
  echo "======================================================================================="
  $VENVBIN/pip install ${ADDONS} ${PIP_PARAMS}
fi

# Handle development addons
if [[ -v DEVELOP ]]; then
  echo "======================================================================================="
  echo "Installing DEVELOPment addons ${DEVELOP}"
  echo "THIS IS NOT MEANT TO BE USED IN PRODUCTION"
  echo "Read about it: https://6.docs.plone.org/install/containers/images/backend.html"
  echo "======================================================================================="
  PACKAGES=""
  while read -ra DEVADDONS; do
    for a in "${DEVADDONS[@]}"; do
      PACKAGES+=" --editable ${a}"
    done
  done <<< "$DEVELOP"
  $VENVBIN/pip install ${PACKAGES} ${PIP_PARAMS}
fi

if [[ "$1" == "start" ]]; then
  # Handle Site creation
  if [[ -v SITE ]]; then
    export TYPE=${TYPE:-volto}
    echo "======================================================================================="
    echo "Creating Plone ${TYPE} SITE: ${SITE}"
    echo "Aditional profiles: ${PROFILES}"
    echo "THIS IS NOT MEANT TO BE USED IN PRODUCTION"
    echo "Read about it: https://6.docs.plone.org/install/containers/images/backend.html"
    echo "======================================================================================="
    export SITE_ID=${SITE}
    $sudo $VENVBIN/zconsole run etc/${CONF} /app/scripts/create_site.py
  fi
  echo $MSG
  if [[ -v LISTEN_PORT ]] ; then
    # Ensure the listen port can be set via container --environment.
    # Necessary to run multiple backends in a single Podman / Kubernetes pod.
    sed -i "s/port = 8080/port = ${LISTEN_PORT}/" etc/zope.ini
  fi
  exec $sudo $VENVBIN/runwsgi -v etc/zope.ini config_file=${CONF}
elif  [[ "$1" == "create-classic" ]]; then
  export TYPE=classic
  exec $sudo $VENVBIN/zconsole run etc/${CONF} /app/scripts/create_site.py
elif  [[ "$1" == "create-volto" ]]; then
  export TYPE=volto
  exec $sudo $VENVBIN/zconsole run etc/${CONF} /app/scripts/create_site.py
elif  [[ "$1" == "create-site" ]]; then
  export TYPE=${TYPE:-volto}
  exec $sudo $VENVBIN/zconsole run etc/${CONF} /app/scripts/create_site.py
elif  [[ "$1" == "console" ]]; then
  exec $sudo $VENVBIN/zconsole debug etc/${CONF}
elif  [[ "$1" == "run" ]]; then
  exec $sudo $VENVBIN/zconsole run etc/${CONF} "${@:2}"
elif  [[ "$1" == "addzopeuser" ]]; then
  exec $sudo $VENVBIN/addzopeuser -c etc/${CONF} "${@:2}"
elif  [[ "$1" == "pack" ]]; then
  if [[ -v ZEO_ADDRESS ]]; then
    exec $sudo $VENVBIN/zeopack "${@:2}" ${ZEO_ADDRESS}
  elif [[ -v RELSTORAGE_DSN ]]; then
    exec $sudo $VENVBIN/zodbpack "${@:2}" etc/relstorage_pack.conf
  else
    exec $sudo $VENVBIN/zconsole run etc/${CONF} /app/scripts/pack.py
  fi
else
  # Custom
  exec "$@"
fi
