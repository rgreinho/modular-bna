#!/bin/bash
set -euo pipefail
[ -n "${PFB_DEBUG}" ] && set -x

PFB_SHPFILE="${1}"
PFB_OSM_FILE="${2}"
PFB_COUNTRY="${3}"
PFB_STATE="${4}"
PFB_STATE_FIPS="${5}"

../import/import_neighborhood.sh "$PFB_SHPFILE" "$PFB_COUNTRY" "$PFB_STATE" "$PFB_STATE_FIPS"
if [ "$RUN_IMPORT_JOBS" == "1" ]; then
  ../import/import_jobs.sh "$PFB_COUNTRY" "$PFB_STATE"
else
  echo "Skipping Importing Jobs"
fi
../import/import_osm.sh "$PFB_OSM_FILE
"
