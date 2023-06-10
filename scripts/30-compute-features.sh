#!/bin/bash
set -euo pipefail
[ "${PFB_DEBUG}" -eq "1" ] && set -x

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
