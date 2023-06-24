#!/bin/bash
set -euo pipefail
[ "${PFB_DEBUG}" -eq "1" ] && set -x

GIT_ROOT=$(git rev-parse --show-toplevel)
# NB_TEMPDIR="test/data"
NB_MAX_TRIP_DISTANCE=2680
NB_BOUNDARY_BUFFER=$NB_MAX_TRIP_DISTANCE

# Function to import a shapefile (using 'dump' mode for quickness) and convert it to the target SRID
function import_and_transform_shapefile() {
  IMPORT_FILE="${1}"
  IMPORT_TABLENAME="${2}"
  IMPORT_SRID="${3:-4326}"

  echo "START: Importing ${IMPORT_TABLENAME}"
  # https://manpages.debian.org/stretch/postgis/shp2pgsql.1.en.html
  shp2pgsql -c -I -D -s "${IMPORT_SRID}" "${IMPORT_FILE}" "${IMPORT_TABLENAME}" | psql
  # shp2pgsql -I -d -D -s "${IMPORT_SRID}" "${IMPORT_FILE}" "${IMPORT_TABLENAME}" | psql
  psql -c "ALTER TABLE ${IMPORT_TABLENAME} ALTER COLUMN geom \
            TYPE geometry(MultiPolygon,${NB_OUTPUT_SRID}) USING ST_Force2d(ST_Transform(geom,${NB_OUTPUT_SRID}));"
  # remyg: do we need the alter command if we specify the output SRID in the shp2pgsql command? -s"${IMPORT_SRID}:${NB_OUTPUT_SRID}"
  echo "DONE: Importing ${IMPORT_TABLENAME}"
}

# Import neighborhood boundary
import_and_transform_shapefile "${NB_BOUNDARY_FILE}" neighborhood_boundary "${NB_INPUT_SRID}"

NB_COUNTRY=$(echo "$NB_COUNTRY" | tr '[:lower:]' '[:upper:]')
if [ "${NB_COUNTRY}" == "USA" ]; then
  echo "IMPORTING: Downloading water blocks"
  psql <"${GIT_ROOT}/sql/create_us_water_blocks_table.sql"
  psql -c "\copy water_blocks FROM '${NB_TEMPDIR}/censuswaterblocks.csv' delimiter ',' csv header;"
  echo "DONE: Importing water blocks"
fi

# Import block shapefile
echo "IMPORTING: Loading census blocks"
import_and_transform_shapefile "${NB_TEMPDIR}/population.shp" neighborhood_census_blocks 4326

# Only keep blocks in boundary+buffer
echo "IMPORTING: Applying boundary buffer"
echo "START: Removing blocks outside buffer with size ${NB_BOUNDARY_BUFFER}"
psql -c "DELETE FROM neighborhood_census_blocks AS blocks USING neighborhood_boundary \
        AS boundary WHERE NOT ST_DWithin(blocks.geom, boundary.geom, \
        ${NB_BOUNDARY_BUFFER});"
echo "DONE: Finished removing blocks outside buffer"

if [ "${NB_COUNTRY}" == "USA" ]; then
  # Discard blocks that are all water / no land area
  echo "IMPORTING: Removing water blocks"
  echo "START: Removing blocks that are 100% water from analysis"
  psql -c "DELETE FROM neighborhood_census_blocks AS blocks USING water_blocks \
           AS water WHERE blocks.BLOCKID10 = water.geoid;"
  echo "DONE: FINISHED removing blocks that are 100% water"
fi

POPULATION=$(psql -t -c "SELECT SUM(pop10) FROM neighborhood_census_blocks;")
echo "Population is ${POPULATION}"
if [[ $POPULATION -eq 0 ]]; then
  echo "Error: Total population of included census blocks is zero."
  exit 1
fi
