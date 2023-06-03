#!/bin/bash
set -euo pipefail
[ -n "${PFB_DEBUG}" ] && set -x


# NB_MAX_TRIP_DISTANCE should be in the same units of the NB_OUTPUT_SRID projection
# Typically meters because we autodetect and use UTM zones
export NB_MAX_TRIP_DISTANCE="${NB_MAX_TRIP_DISTANCE:-2680}"
# Same units as NB_MAX_TRIP_DISTANCE
export NB_BOUNDARY_BUFFER="${NB_BOUNDARY_BUFFER:-$NB_MAX_TRIP_DISTANCE}"
export PFB_POP_URL="${PFB_POP_URL:-}"
export PFB_JOB_URL="${PFB_JOB_URL:-}"
export RUN_IMPORT_JOBS="${RUN_IMPORT_JOBS:-1}"
export PFB_COUNTRY="${PFB_COUNTRY:-USA}"

PFB_TEMPDIR="${NB_TEMPDIR:-$(mktemp -d)}"
mkdir -p "${PFB_TEMPDIR}"

# run job

# determine coordinate reference system based on input shapefile UTM zone
export NB_OUTPUT_SRID="$(./scripts/detect_utm_zone.py $PFB_SHPFILE)"
./scripts/import.sh $PFB_SHPFILE $PFB_OSM_FILE $PFB_COUNTRY $PFB_STATE $PFB_STATE_FIPS
./scripts/run_connectivity.sh

# print scores
psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" <<EOF
SELECT * FROM neighborhood_overall_scores;
EOF

EXPORT_DIR="${NB_OUTPUT_DIR:-$PFB_TEMPDIR/output}"
if [ -n "${PFB_JOB_ID}" ]
then
    EXPORT_DIR="${EXPORT_DIR}/${PFB_JOB_ID}"
else
    EXPORT_DIR="${EXPORT_DIR}/local-analysis-`date +%F-%H%M`"
fi
./scripts/export_connectivity.sh $EXPORT_DIR

rm -rf "${PFB_TEMPDIR}"

popd

# Use official environment variables instead:
# PGHOST behaves the same as the host connection parameter.
# PGHOSTADDR behaves the same as the hostaddr connection parameter. This can be
#   set instead of or in addition to PGHOST to avoid DNS lookup overhead.
# PGPORT behaves the same as the port connection parameter.
# PGDATABASE behaves the same as the dbname connection parameter.
# PGUSER behaves the same as the user connection parameter.
# PGPASSWORD behaves the same as the password connection parameter. Use of this
#   environment variable is not recommended for security reasons, as some
#   operating systems allow non-root users to see process environment variables
#   via ps; instead consider using a password file (see Section 34.16).
