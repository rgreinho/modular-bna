#!/usr/bin/env bash
set -euo pipefail
[ "${PFB_DEBUG}" -eq "1" ] && set -x

CORES=$(python -c "import multiprocessing; print(multiprocessing.cpu_count());")
GIT_ROOT=$(git rev-parse --show-toplevel)
NB_OUTPUT_SRID="${NB_OUTPUT_SRID:-2163}"
NB_SIGCTL_SEARCH_DIST="${NB_SIGCTL_SEARCH_DIST:-25}" # max search distance for intersection controls
NB_MAX_TRIP_DISTANCE="${NB_MAX_TRIP_DISTANCE:-2680}"
NB_BOUNDARY_BUFFER="${NB_BOUNDARY_BUFFER:-$NB_MAX_TRIP_DISTANCE}"
PFB_RESIDENTIAL_SPEED_LIMIT="${PFB_RESIDENTIAL_SPEED_LIMIT:-}"

# Get the neighborhood_boundary bbox as extent of trimmed census blocks
BBOX=$(psql -t -c "select ST_Extent(ST_Transform(geom, 4326)) from neighborhood_census_blocks;" | awk -F '[()]' '{print $2}' | tr " " ",")
echo "CLIPPING OSM TO: ${BBOX}"

OSM_TEMPDIR="${NB_TEMPDIR:-$(mktemp -d)}/import_osm"
mkdir -p "${OSM_TEMPDIR}"

echo "IMPORTING Clipping provided OSM file"
OSM_DATA_FILE="${OSM_TEMPDIR}/converted.osm"
osmconvert "${1}" \
  --drop-broken-refs \
  -b="${BBOX}" \
  -o="${OSM_DATA_FILE}"
# If the OSM file contains "\" as a segment name, osm2pgrouting chokes on those segments and drops
# everything that happens to be in the same processing chunk. So strip them out.
sed 's/\\/backslash/' "$OSM_DATA_FILE" >"${OSM_DATA_FILE}-cleaned"
mv "${OSM_DATA_FILE}-cleaned" "$OSM_DATA_FILE"

# import the osm with highways
echo "IMPORTING Importing OSM data"
osm2pgrouting \
  -f "$OSM_DATA_FILE" \
  -h "$PGHOST" \
  --dbname "${PGDATABASE}" \
  --username "${PGUSER}" \
  --password "${PGPASSWORD}" \
  --schema received \
  --prefix neighborhood_ \
  --conf "${GIT_ROOT}/scripts/mapconfig_highway.xml" \
  --clean

# import the osm with cycleways that the above misses (bug in osm2pgrouting)
osm2pgrouting \
  -f "$OSM_DATA_FILE" \
  -h "$PGHOST" \
  --dbname "${PGDATABASE}" \
  --username "${PGUSER}" \
  --password "${PGPASSWORD}" \
  --schema scratch \
  --prefix neighborhood_cycwys_ \
  --conf "${GIT_ROOT}/scripts/mapconfig_cycleway.xml" \
  --clean

# rename a few tables (or drop if not needed)
echo 'Renaming tables'
psql -c "ALTER TABLE received.neighborhood_ways_vertices_pgr RENAME TO neighborhood_ways_intersections;"
psql -c "ALTER TABLE received.neighborhood_ways_intersections RENAME CONSTRAINT neighborhood_ways_vertices_pgr_osm_id_key TO neighborhood_vertex_id;"
psql -c "ALTER TABLE scratch.neighborhood_cycwys_ways_vertices_pgr RENAME CONSTRAINT neighborhood_cycwys_ways_vertices_pgr_osm_id_key TO neighborhood_vertex_id;"

# import full osm to fill out additional data needs
# not met by osm2pgrouting

# import
osm2pgsql \
  --create \
  --prefix "neighborhood_osm_full" \
  --proj "${NB_OUTPUT_SRID}" \
  --style "${GIT_ROOT}/scripts/pfb.style" \
  --number-processes "${CORES}" \
  "${OSM_DATA_FILE}"

# Delete downloaded temp OSM data
rm -rf "${OSM_TEMPDIR}"

# Create table for state residential speeds
echo 'START: Importing State Default Speed Table'
psql <"${GIT_ROOT}/sql/speed_tables.sql"

# Import state residential speeds file
STATE_SPEED_DOWNLOAD="${NB_TEMPDIR}/state_fips_speed.csv"
if [ -e "${STATE_SPEED_DOWNLOAD}" ]; then
  psql -c "\copy state_speed FROM '${STATE_SPEED_DOWNLOAD}' delimiter ',' csv header"
  # Set default residential speed for state
  STATE_DEFAULT=$(psql -t -c "SELECT state_speed.speed FROM state_speed WHERE state_speed.fips_code_state = '${PFB_STATE_FIPS}'")
fi

if [ -z "$STATE_DEFAULT" ]; then
  STATE_DEFAULT=NULL
fi
echo "DONE: Importing state default residential speed"

# Create table for city residential speeds
echo 'START: Importing City Default Speed Table'
CITY_SPEED_DOWNLOAD="${NB_TEMPDIR}/city_fips_speed.csv"
if [ -e "${CITY_SPEED_DOWNLOAD}" ]; then
  psql -c "\copy city_speed FROM '${CITY_SPEED_DOWNLOAD}' delimiter ',' csv header"
  # Set default residential speed for city
  CITY_DEFAULT=$(psql -t -c "SELECT city_speed.speed FROM city_speed WHERE city_speed.fips_code_city = '${PFB_CITY_FIPS}'")
fi

if [ -n "${PFB_RESIDENTIAL_SPEED_LIMIT}" ]; then
  # If the speed limit is provided, set/override the city speed limit with that.
  echo "Setting city speed limit to provided residential speed limit (${PFB_RESIDENTIAL_SPEED_LIMIT})"
  CITY_DEFAULT=$PFB_RESIDENTIAL_SPEED_LIMIT
fi

# Check if no value for city default, if so set to NULL
if [[ -z "$CITY_DEFAULT" ]]; then
  echo "No default residential speed in city."
  CITY_DEFAULT=NULL
else
  echo "The city residential default speed is ${CITY_DEFAULT}."
fi

# Save default speed limit to a table for export later
psql <<SQL
INSERT INTO "residential_speed_limit" (
    state_fips_code,
    city_fips_code,
    state_speed,
    city_speed
) VALUES (
    ${PFB_STATE_FIPS},
    ${PFB_CITY_FIPS},
    ${STATE_DEFAULT},
    ${CITY_DEFAULT}
);
SQL
echo "DONE: Importing default residential speed limit"

# move the full osm tables to the received schema
echo 'Moving tables to received schema'
psql -c "ALTER TABLE generated.neighborhood_osm_full_line SET SCHEMA received;"
psql -c "ALTER TABLE generated.neighborhood_osm_full_point SET SCHEMA received;"
psql -c "ALTER TABLE generated.neighborhood_osm_full_polygon SET SCHEMA received;"
psql -c "ALTER TABLE generated.neighborhood_osm_full_roads SET SCHEMA received;"
