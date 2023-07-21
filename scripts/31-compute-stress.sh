#!/bin/bash
set -euo pipefail
[ "${PFB_DEBUG}" -eq "1" ] && set -x

GIT_ROOT=$(git rev-parse --show-toplevel)
STATE_DEFAULT=$(psql -t -c "SELECT state_speed FROM residential_speed_limit WHERE city_fips_code = '${PFB_CITY_FIPS}'" | tr -d '[:space:]')
if [ -z "${STATE_DEFAULT}" ]; then
  STATE_DEFAULT=NULL
fi
CITY_DEFAULT=$(psql -t -c "SELECT city_speed FROM residential_speed_limit WHERE city_fips_code = '${PFB_CITY_FIPS}'" | tr -d '[:space:]')
if [ -z "${CITY_DEFAULT}" ]; then
  CITY_DEFAULT=NULL
fi

echo 'Calculating stress'
psql -f "${GIT_ROOT}"/sql/stress/stress_motorway-trunk.sql
# primary
psql -v class=primary -v default_speed=40 -v default_lanes=2 \
  -v default_parking=1 -v default_parking_width=8 -v default_facility_width=5 \
  -f "${GIT_ROOT}"/sql/stress/stress_segments_higher_order.sql
# secondary
psql -v class=secondary -v default_speed=40 -v default_lanes=2 \
  -v default_parking=1 -v default_parking_width=8 -v default_facility_width=5 \
  -f "${GIT_ROOT}"/sql/stress/stress_segments_higher_order.sql
# tertiary
psql -v class=tertiary -v default_speed=30 -v default_lanes=1 \
  -v default_parking=1 -v default_parking_width=8 -v default_facility_width=5 \
  -f "${GIT_ROOT}"/sql/stress/stress_segments_higher_order.sql
# residential
psql -v class=residential -v default_lanes=1 \
  -v default_parking=1 -v default_roadway_width=27 \
  -v state_default="${STATE_DEFAULT}" -v city_default="${CITY_DEFAULT}" \
  -f "${GIT_ROOT}"/sql/stress/stress_segments_lower_order_res.sql
# unclassified
psql -v class=unclassified -v default_speed=25 -v default_lanes=1 \
  -v default_parking=1 -v default_roadway_width=27 \
  -f "${GIT_ROOT}"/sql/stress/stress_segments_lower_order.sql
psql -f "${GIT_ROOT}"/sql/stress/stress_living_street.sql
psql -f "${GIT_ROOT}"/sql/stress/stress_track.sql
psql -f "${GIT_ROOT}"/sql/stress/stress_path.sql
psql -f "${GIT_ROOT}"/sql/stress/stress_one_way_reset.sql
psql -f "${GIT_ROOT}"/sql/stress/stress_motorway-trunk_ints.sql
psql -f "${GIT_ROOT}"/sql/stress/stress_primary_ints.sql
psql -f "${GIT_ROOT}"/sql/stress/stress_secondary_ints.sql
# tertiary intersections
psql -v primary_speed=40 \
  -v secondary_speed=40 \
  -v primary_lanes=2 \
  -v secondary_lanes=2 \
  -f "${GIT_ROOT}"/sql/stress/stress_tertiary_ints.sql
psql -v primary_speed=40 \
  -v secondary_speed=40 \
  -v tertiary_speed=30 \
  -v primary_lanes=2 \
  -v secondary_lanes=2 \
  -v tertiary_lanes=1 \
  -f "${GIT_ROOT}"/sql/stress/stress_lesser_ints.sql
psql -f "${GIT_ROOT}"/sql/stress/stress_link_ints.sql
