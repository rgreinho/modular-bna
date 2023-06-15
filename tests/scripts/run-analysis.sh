#!/bin/bash
set -euo pipefail
[ "${PFB_DEBUG}" -eq "1" ] && set -x

# Define the city to analyse.
# This is the only section that shouldbe edited!
# BNA_CITY="provincetown"
# BNA_SHORT_STATE="ma"
# BNA_FULL_STATE="massachusetts"
# BNA_STATE_FIPS=25
# BNA_CITY_FIPS=555535
# BNA_COUNTRY="USA"

# Define the root of this repository.
GIT_ROOT=$(git rev-parse --show-toplevel)

# Compute variables to reduce the risk of typos.
BNA_TESTS_DIR="${GIT_ROOT}/tests"
BNA_SAMPLES_DIR="${BNA_TESTS_DIR}/samples"
BNA_CITY_DIR="${BNA_SAMPLES_DIR}/${BNA_CITY}-${BNA_FULL_STATE}"
BNA_OUTPUT_DIR="${BNA_CITY_DIR}/outputs/modular-bna"
BNA_CITY_DATA="${BNA_CITY_DIR}/data"
BNA_CITY_DATA_FILE="${BNA_CITY_DATA}/${BNA_CITY}-${BNA_FULL_STATE}"
BNA_OSM_FILE="${BNA_CITY_DATA_FILE}.osm"
BNA_BOUNDARY_FILE="${BNA_CITY_DATA_FILE}.shp"

# Define the variables required by the original BNA scripts.
export CENSUS_YEAR=2019
export CITY_DEFAULT=NULL
export NB_BOUNDARY_FILE="${BNA_BOUNDARY_FILE}"
export NB_COUNTRY="${BNA_COUNTRY}"
export NB_INPUT_SRID=4236
export NB_OUTPUT_SRID=2163
export NB_TEMPDIR="${BNA_CITY_DATA}"
export PFB_CITY_FIPS="${BNA_CITY_FIPS}"
export PFB_STATE_FIPS="${BNA_STATE_FIPS}"
export PFB_STATE="${BNA_SHORT_STATE}"
export RUN_IMPORT_JOBS=1
export STATE_DEFAULT=30

# Prepare.
bash -x "${GIT_ROOT}/scripts/01-setup_database.sh"

# Import.
bash -x "${GIT_ROOT}/scripts/21-import_neighborhood.sh"
bash -x "${GIT_ROOT}/scripts/22-import_jobs.sh"
bash -x "${GIT_ROOT}/scripts/23-import_osm.sh" "${BNA_OSM_FILE}"

# Compute.
bash -x "${GIT_ROOT}/scripts/30-compute-features.sh"
bash -x "${GIT_ROOT}/scripts/31-compute-stress.sh"
bash -x "${GIT_ROOT}/scripts/32-compute-run-connectivity.sh"

# Export.
rm -fr "${BNA_OUTPUT_DIR}"
mkdir -p "${BNA_OUTPUT_DIR}"
bash -x "${GIT_ROOT}/scripts/40-export-export_connectivity.sh" "${BNA_OUTPUT_DIR}"
