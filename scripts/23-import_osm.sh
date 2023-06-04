#!/usr/bin/env bash
set -euo pipefail
[ "${PFB_DEBUG}" -eq "1" ] && set -x

cd "$(dirname "$0")"

# NB_POSTGRESQL_HOST="${NB_POSTGRESQL_HOST:-127.0.0.1}"
# NB_POSTGRESQL_DB="${NB_POSTGRESQL_DB:-pfb}"
# NB_POSTGRESQL_USER="${NB_POSTGRESQL_USER:-gis}"
# NB_POSTGRESQL_PASSWORD="${NB_POSTGRESQL_PASSWORD:-gis}"
NB_OUTPUT_SRID="${NB_OUTPUT_SRID:-2163}"
NB_SIGCTL_SEARCH_DIST="${NB_SIGCTL_SEARCH_DIST:-25}" # max search distance for intersection controls
NB_MAX_TRIP_DISTANCE="${NB_MAX_TRIP_DISTANCE:-2680}"
NB_BOUNDARY_BUFFER="${NB_BOUNDARY_BUFFER:-$NB_MAX_TRIP_DISTANCE}"
PFB_STATE_FIPS="${PFB_STATE_FIPS:-NULL}"
PFB_CITY_FIPS="${PFB_CITY_FIPS:-0}"
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
  -h "$NB_POSTGRESQL_HOST" \
  --dbname "${NB_POSTGRESQL_DB}" \
  --username "${NB_POSTGRESQL_USER}" \
  --schema received \
  --prefix neighborhood_ \
  --conf ./mapconfig_highway.xml \
  --clean

# import the osm with cycleways that the above misses (bug in osm2pgrouting)
osm2pgrouting \
  -f "$OSM_DATA_FILE" \
  -h "$NB_POSTGRESQL_HOST" \
  --dbname "${NB_POSTGRESQL_DB}" \
  --username "${NB_POSTGRESQL_USER}" \
  --schema scratch \
  --prefix neighborhood_cycwys_ \
  --conf ./mapconfig_cycleway.xml \
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
  --host "${NB_POSTGRESQL_HOST}" \
  --username "${NB_POSTGRESQL_USER}" \
  --port 5432 \
  --create \
  --database "${NB_POSTGRESQL_DB}" \
  --prefix "neighborhood_osm_full" \
  --proj "${NB_OUTPUT_SRID}" \
  --style ./pfb.style \
  "${OSM_DATA_FILE}"

# Delete downloaded temp OSM data
rm -rf "${OSM_TEMPDIR}"

# Create table for state residential speeds
echo 'START: Importing State Default Speed Table'
psql <../sql/state_speed_table.sql

SPEED_TEMPDIR="${NB_TEMPDIR:-$(mktemp -d)}/speed"
mkdir -p "${SPEED_TEMPDIR}"

# Import state residential speeds file
STATE_SPEED_FILENAME="state_fips_speed"
STATE_SPEED_DOWNLOAD="${SPEED_TEMPDIR}/${STATE_SPEED_FILENAME}.csv"
psql -c "\copy state_speed FROM ${STATE_SPEED_DOWNLOAD} delimiter ',' csv header"

# Set default residential speed for state
STATE_DEFAULT=$(psql -t -c "SELECT state_speed.speed FROM state_speed WHERE state_speed.fips_code_state = '${PFB_STATE_FIPS}'")
if [ -z "$STATE_DEFAULT" ]; then
  STATE_DEFAULT=NULL
fi
echo "DONE: Importing state default residential speed"

# Create table for city residential speeds
echo 'START: Importing City Default Speed Table'

CITY_SPEED_FILENAME="city_fips_speed"
CITY_SPEED_DOWNLOAD="/data/${CITY_SPEED_FILENAME}.csv"
psql -c "\copy city_speed FROM ${CITY_SPEED_DOWNLOAD} delimiter ',' csv header"

# Set default residential speed for city
CITY_DEFAULT=$(psql -t -c "SELECT city_speed.speed FROM city_speed WHERE city_speed.fips_code_city = '${PFB_CITY_FIPS}'")

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
psql -c "INSERT INTO \"residential_speed_limit\" (
            state_fips_code,
            city_fips_code,
            state_speed,
            city_speed
        ) VALUES (
          ${PFB_STATE_FIPS},
          ${PFB_CITY_FIPS},
          ${STATE_DEFAULT},
          ${CITY_DEFAULT}
        );"

echo "DONE: Importing default residential speed limit"

# move the full osm tables to the received schema
echo 'Moving tables to received schema'
psql -c "ALTER TABLE generated.neighborhood_osm_full_line SET SCHEMA received;"
psql -c "ALTER TABLE generated.neighborhood_osm_full_point SET SCHEMA received;"
psql -c "ALTER TABLE generated.neighborhood_osm_full_polygon SET SCHEMA received;"
psql -c "ALTER TABLE generated.neighborhood_osm_full_roads SET SCHEMA received;"

# process tables
echo 'Updating field names'
psql -v nb_output_srid="${NB_OUTPUT_SRID}" -f ./prepare_tables.sql
echo 'Clipping OSM source data to boundary + buffer'
psql -v nb_boundary_buffer="${NB_BOUNDARY_BUFFER}" -f ./clip_osm.sql
echo 'Removing paths that prohibit bicycles'
psql -c "DELETE FROM neighborhood_osm_full_line WHERE bicycle='no' and highway='path';"
echo 'Setting values on road segments'
psql -f ../features/one_way.sql
psql -f ../features/width_ft.sql
psql -f ../features/functional_class.sql
psql -v nb_output_srid="${NB_OUTPUT_SRID}" -f ../features/paths.sql
psql -f ../features/speed_limit.sql
psql -f ../features/lanes.sql
psql -f ../features/park.sql
psql -f ../features/bike_infra.sql
psql -f ../features/class_adjustments.sql
echo 'Setting values on intersections'
psql -f ../features/legs.sql
psql -v sigctl_search_dist="${NB_SIGCTL_SEARCH_DIST}" -f ../features/signalized.sql
psql -v sigctl_search_dist="${NB_SIGCTL_SEARCH_DIST}" -f ../features/stops.sql
psql -v sigctl_search_dist="${NB_SIGCTL_SEARCH_DIST}" -f ../features/rrfb.sql
psql -v sigctl_search_dist="${NB_SIGCTL_SEARCH_DIST}" -f ../features/island.sql
echo 'Calculating stress'
psql -f ../stress/stress_motorway-trunk.sql
# primary
psql -v class=primary -v default_speed=40 -v default_lanes=2 \
  -v default_parking=1 -v default_parking_width=8 -v default_facility_width=5 \
  -f ../stress/stress_segments_higher_order.sql
# secondary
psql -v class=secondary -v default_speed=40 -v default_lanes=2 \
  -v default_parking=1 -v default_parking_width=8 -v default_facility_width=5 \
  -f ../stress/stress_segments_higher_order.sql
# tertiary
psql -v class=tertiary -v default_speed=30 -v default_lanes=1 \
  -v default_parking=1 -v default_parking_width=8 -v default_facility_width=5 \
  -f ../stress/stress_segments_higher_order.sql
# residential
psql -v class=residential -v default_lanes=1 \
  -v default_parking=1 -v default_roadway_width=27 \
  -v state_default="${STATE_DEFAULT}" -v city_default="${CITY_DEFAULT}" \
  -f ../stress/stress_segments_lower_order_res.sql
# unclassified
psql -v class=unclassified -v default_speed=25 -v default_lanes=1 \
  -v default_parking=1 -v default_roadway_width=27 \
  -f ../stress/stress_segments_lower_order.sql
psql -f ../stress/stress_living_street.sql
psql -f ../stress/stress_track.sql
psql -f ../stress/stress_path.sql
psql -f ../stress/stress_one_way_reset.sql
psql -f ../stress/stress_motorway-trunk_ints.sql
psql -f ../stress/stress_primary_ints.sql
psql -f ../stress/stress_secondary_ints.sql
# tertiary intersections
psql -v primary_speed=40 \
  -v secondary_speed=40 \
  -v primary_lanes=2 \
  -v secondary_lanes=2 \
  -f ../stress/stress_tertiary_ints.sql
psql -v primary_speed=40 \
  -v secondary_speed=40 \
  -v tertiary_speed=30 \
  -v primary_lanes=2 \
  -v secondary_lanes=2 \
  -v tertiary_lanes=1 \
  -f ../stress/stress_lesser_ints.sql
psql -f ../stress/stress_link_ints.sql
