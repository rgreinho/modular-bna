#!/bin/bash
set -euo pipefail
[ "${PFB_DEBUG}" -eq "1" ] && set -x

GIT_ROOT=$(git rev-parse --show-toplevel)
IMPORT_SRID=4326
NB_MAX_TRIP_DISTANCE=2680
NB_BOUNDARY_BUFFER=$NB_MAX_TRIP_DISTANCE
NB_COUNTRY=$(echo "$NB_COUNTRY" | tr '[:lower:]' '[:upper:]')
SHP2PGSQL_CMD="shp2pgsql -d -I -D -s ${IMPORT_SRID}:${NB_OUTPUT_SRID}"

# Import neighborhood boundary.
echo "IMPORTING: Loading neighborhood boundary: ${NB_BOUNDARY_FILE}"
${SHP2PGSQL_CMD} "${NB_BOUNDARY_FILE}" neighborhood_boundary | psql

# Import waterblocks.
if [ "${NB_COUNTRY}" == "USA" ]; then
  echo "IMPORTING: Downloading water blocks"
  psql <"${GIT_ROOT}/sql/create_us_water_blocks_table.sql"
  psql -c "\copy water_blocks FROM '${NB_TEMPDIR}/censuswaterblocks.csv' delimiter ',' csv header;"
  echo "DONE: Importing water blocks"
fi

# Import block shapefile
echo "IMPORTING: Loading census blocks"
${SHP2PGSQL_CMD} "${NB_TEMPDIR}/population.shp" neighborhood_census_blocks | psql

# Only keep blocks in boundary+buffer
echo "START: Removing blocks outside buffer with size ${NB_BOUNDARY_BUFFER}"
psql <<SQL
DELETE FROM neighborhood_census_blocks AS blocks
USING neighborhood_boundary AS boundary
WHERE NOT ST_DWITHIN(blocks.geom, boundary.geom, ${NB_BOUNDARY_BUFFER});
SQL
echo "DONE: Finished removing blocks outside buffer"

# Discard blocks that are all water / no land area
if [ "${NB_COUNTRY}" == "USA" ]; then
  echo "START: Removing blocks that are 100% water from analysis"
  psql <<SQL
DELETE FROM neighborhood_census_blocks AS blocks
USING water_blocks AS water
WHERE blocks.blockid10 = water.geoid;
SQL
  echo "DONE: FINISHED removing blocks that are 100% water"
fi

POPULATION=$(psql -t -c "SELECT SUM(pop10) FROM neighborhood_census_blocks;")
echo "Population is ${POPULATION}"
if [ "$POPULATION" -eq 0 ]; then
  echo "Error: Total population of included census blocks is zero."
  exit 1
fi
