#!/bin/bash
set -euo pipefail
[ "${PFB_DEBUG}" -eq "1" ] && set -x

function import_job_data() {
  # Data type is either 'main' or 'aux'.
  DATA_TYPE="${1}"
  JOB_FILENAME="${PFB_STATE}_od_${DATA_TYPE}_JT00_${CENSUS_YEAR}.csv"
  JOB_FILEPATH=${NB_TEMPDIR}/${JOB_FILENAME}

  # Create the table.
  TABLE=state_od_${DATA_TYPE}_JT00
  psql -c "DROP TABLE IF EXISTS ${TABLE};"
  psql <<SQL
CREATE TABLE ${TABLE} (
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
);
SQL

  # Load data.
  psql -c "\copy ${TABLE} FROM '${JOB_FILEPATH}' DELIMITER ',' CSV HEADER;"
}

echo "Importing jobs data"
import_job_data "main"
import_job_data "aux"
