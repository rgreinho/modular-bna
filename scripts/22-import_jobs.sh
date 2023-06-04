#!/bin/bash
set -euo pipefail
[ "${PFB_DEBUG}" -eq "1" ] && set -x

function import_job_data() {
  # Force to lower case to match the jobs file download paths.
  PFB_STATE="${1,,}"
  # Data type is either 'main' or 'aux'.
  DATA_TYPE="${2:-main}"
  JOB_FILENAME="${PFB_STATE}_od_${DATA_TYPE}_JT00_${CENSUS_YEAR}.csv"
  TEMPDIR="test/usa-az-flagstaff"
  JOB_FILEPATH=${TEMPDIR}/${JOB_FILENAME}

  # Create the table.
  TABLE=state_od_${DATA_TYPE}_JT00
  psql -c "DROP TABLE IF EXISTS ${TABLE};"
  psql -c "CREATE TABLE ${TABLE} (
    w_geocode varchar(15),
    h_geocode varchar(15),
    S000 integer,
    SA01 integer,
    SA02 integer,
    SA03 integer,
    SE01 integer,
    SE02 integer,
    SE03 integer,
    SI01 integer,
    SI02 integer,
    SI03 integer,
    createdate varchar(32)
);"

  # Load data.
  psql -c "\copy ${TABLE} FROM '${JOB_FILEPATH}' DELIMITER ',' CSV HEADER"
}

echo "Importing jobs data"
import_job_data "${PFB_STATE}" "main"
import_job_data "${PFB_STATE}" "aux"

# NB_POSTGRESQL_HOST="${NB_POSTGRESQL_HOST:-127.0.0.1}"
# NB_POSTGRESQL_DB="${NB_POSTGRESQL_DB:-pfb}"
# NB_POSTGRESQL_USER="${NB_POSTGRESQL_USER:-gis}"
# NB_POSTGRESQL_PASSWORD="${NB_POSTGRESQL_PASSWORD:-gis}"

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

#CENSUS_YEAR
