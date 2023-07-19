#!/bin/bash
set -euo pipefail
[ "${PFB_DEBUG}" -eq "1" ] && set -x

GIT_ROOT=$(git rev-parse --show-toplevel)

NB_SIGCTL_SEARCH_DIST="${NB_SIGCTL_SEARCH_DIST:-25}"
NB_MAX_TRIP_DISTANCE="${NB_MAX_TRIP_DISTANCE:-2680}"
NB_BOUNDARY_BUFFER="${NB_BOUNDARY_BUFFER:-$NB_MAX_TRIP_DISTANCE}"

echo 'Updating field names'
psql -v nb_output_srid="${NB_OUTPUT_SRID}" -f "${GIT_ROOT}"/sql/prepare_tables.sql

echo 'Clipping OSM source data to boundary + buffer'
psql -v nb_boundary_buffer="${NB_BOUNDARY_BUFFER}" -f "${GIT_ROOT}"/sql/clip_osm.sql

echo 'Removing paths that prohibit bicycles'
psql -c "DELETE FROM neighborhood_osm_full_line WHERE bicycle='no' and highway='path';"

echo 'Setting values on road segments'
psql -f "${GIT_ROOT}"/sql/features/one_way.sql
psql -f "${GIT_ROOT}"/sql/features/width_ft.sql
psql -f "${GIT_ROOT}"/sql/features/functional_class.sql
psql -v nb_output_srid="${NB_OUTPUT_SRID}" -f "${GIT_ROOT}"/sql/features/paths.sql
psql -f "${GIT_ROOT}"/sql/features/speed_limit.sql
psql -f "${GIT_ROOT}"/sql/features/lanes.sql
psql -f "${GIT_ROOT}"/sql/features/park.sql
psql -f "${GIT_ROOT}"/sql/features/bike_infra.sql
psql -f "${GIT_ROOT}"/sql/features/class_adjustments.sql

echo 'Setting values on intersections'
psql -f "${GIT_ROOT}"/sql/features/legs.sql
psql -v sigctl_search_dist="${NB_SIGCTL_SEARCH_DIST}" -f "${GIT_ROOT}"/sql/features/signalized.sql
psql -v sigctl_search_dist="${NB_SIGCTL_SEARCH_DIST}" -f "${GIT_ROOT}"/sql/features/stops.sql
psql -v sigctl_search_dist="${NB_SIGCTL_SEARCH_DIST}" -f "${GIT_ROOT}"/sql/features/rrfb.sql
psql -v sigctl_search_dist="${NB_SIGCTL_SEARCH_DIST}" -f "${GIT_ROOT}"/sql/features/island.sql
