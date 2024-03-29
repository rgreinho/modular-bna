#!/bin/bash
set -euo pipefail
[ "${PFB_DEBUG}" -eq "1" ] && set -x

GIT_ROOT=$(git rev-parse --show-toplevel)

NB_OUTPUT_SRID="${NB_OUTPUT_SRID:-2163}"
NB_MAX_TRIP_DISTANCE="${NB_MAX_TRIP_DISTANCE:-2680}"
TOLERANCE_COLLEGES="${TOLERANCE_COLLEGES:-100}"         # cluster tolerance given in units of $NB_OUTPUT_SRID
TOLERANCE_COMM_CTR="${TOLERANCE_COMM_CTR:-50}"          # cluster tolerance given in units of $NB_OUTPUT_SRID
TOLERANCE_DOCTORS="${TOLERANCE_DOCTORS:-50}"            # cluster tolerance given in units of $NB_OUTPUT_SRID
TOLERANCE_DENTISTS="${TOLERANCE_DENTISTS:-50}"          # cluster tolerance given in units of $NB_OUTPUT_SRID
TOLERANCE_HOSPITALS="${TOLERANCE_HOSPITALS:-50}"        # cluster tolerance given in units of $NB_OUTPUT_SRID
TOLERANCE_PHARMACIES="${TOLERANCE_PHARMACIES:-50}"      # cluster tolerance given in units of $NB_OUTPUT_SRID
TOLERANCE_PARKS="${TOLERANCE_PARKS:-50}"                # cluster tolerance given in units of $NB_OUTPUT_SRID
TOLERANCE_RETAIL="${TOLERANCE_RETAIL:-50}"              # cluster tolerance given in units of $NB_OUTPUT_SRID
TOLERANCE_TRANSIT="${TOLERANCE_TRANSIT:-75}"            # cluster tolerance given in units of $NB_OUTPUT_SRID
TOLERANCE_UNIVERSITIES="${TOLERANCE_UNIVERSITIES:-150}" # cluster tolerance given in units of $NB_OUTPUT_SRID
MIN_PATH_LENGTH="${MIN_PATH_LENGTH:-4800}"              # minimum path length to be considered for recreation access
MIN_PATH_BBOX="${MIN_PATH_BBOX:-3300}"                  # minimum corner-to-corner span of path bounding box to be considered for recreation access
BLOCK_ROAD_BUFFER="${BLOCK_ROAD_BUFFER:-15}"            # buffer distance to find roads associated with a block
BLOCK_ROAD_MIN_LENGTH="${BLOCK_ROAD_MIN_LENGTH:-30}"    # minimum length road must overlap with block buffer to be associated
SCORE_TOTAL="${SCORE_TOTAL:-100}"
SCORE_PEOPLE="${SCORE_PEOPLE:-15}"
SCORE_OPPORTUNITY="${SCORE_OPPORTUNITY:-20}"
SCORE_CORESVCS="${SCORE_CORESVCS:-20}"
SCORE_RETAIL="${SCORE_RETAIL:-15}"
SCORE_RECREATION="${SCORE_RECREATION:-15}"
SCORE_TRANSIT="${SCORE_TRANSIT:-15}"

# Limit custom output formatting for `time` command
export TIME="\nTIMING: %C\nTIMING:\t%E elapsed %Kkb mem\n"

echo "BUILDING: Building network"
time psql -v nb_output_srid="${NB_OUTPUT_SRID}" \
  -f "${GIT_ROOT}"/sql/connectivity/build_network.sql

time psql -v nb_output_srid="${NB_OUTPUT_SRID}" \
  -v block_road_buffer="${BLOCK_ROAD_BUFFER}" \
  -v block_road_min_length="${BLOCK_ROAD_MIN_LENGTH}" \
  -f "${GIT_ROOT}"/sql/connectivity/census_blocks.sql

echo "CONNECTIVITY: Reachable roads high stress"
time psql -f "${GIT_ROOT}"/sql/connectivity/reachable_roads_high_stress_prep.sql

psql -v thread_num=8 -v thread_no=0 -v nb_max_trip_distance="${NB_MAX_TRIP_DISTANCE}" -f "${GIT_ROOT}"/sql/connectivity/reachable_roads_high_stress_calc.sql
psql -v thread_num=8 -v thread_no=1 -v nb_max_trip_distance="${NB_MAX_TRIP_DISTANCE}" -f "${GIT_ROOT}"/sql/connectivity/reachable_roads_high_stress_calc.sql
psql -v thread_num=8 -v thread_no=2 -v nb_max_trip_distance="${NB_MAX_TRIP_DISTANCE}" -f "${GIT_ROOT}"/sql/connectivity/reachable_roads_high_stress_calc.sql
psql -v thread_num=8 -v thread_no=3 -v nb_max_trip_distance="${NB_MAX_TRIP_DISTANCE}" -f "${GIT_ROOT}"/sql/connectivity/reachable_roads_high_stress_calc.sql
psql -v thread_num=8 -v thread_no=4 -v nb_max_trip_distance="${NB_MAX_TRIP_DISTANCE}" -f "${GIT_ROOT}"/sql/connectivity/reachable_roads_high_stress_calc.sql
psql -v thread_num=8 -v thread_no=5 -v nb_max_trip_distance="${NB_MAX_TRIP_DISTANCE}" -f "${GIT_ROOT}"/sql/connectivity/reachable_roads_high_stress_calc.sql
psql -v thread_num=8 -v thread_no=6 -v nb_max_trip_distance="${NB_MAX_TRIP_DISTANCE}" -f "${GIT_ROOT}"/sql/connectivity/reachable_roads_high_stress_calc.sql
psql -v thread_num=8 -v thread_no=7 -v nb_max_trip_distance="${NB_MAX_TRIP_DISTANCE}" -f "${GIT_ROOT}"/sql/connectivity/reachable_roads_high_stress_calc.sql

time psql -f "${GIT_ROOT}"/sql/connectivity/reachable_roads_high_stress_cleanup.sql

echo "CONNECTIVITY: Reachable roads low stress"
time psql -f "${GIT_ROOT}"/sql/connectivity/reachable_roads_low_stress_prep.sql

psql -v thread_num=8 -v thread_no=0 -v nb_max_trip_distance="${NB_MAX_TRIP_DISTANCE}" -f "${GIT_ROOT}"/sql/connectivity/reachable_roads_low_stress_calc.sql
psql -v thread_num=8 -v thread_no=1 -v nb_max_trip_distance="${NB_MAX_TRIP_DISTANCE}" -f "${GIT_ROOT}"/sql/connectivity/reachable_roads_low_stress_calc.sql
psql -v thread_num=8 -v thread_no=2 -v nb_max_trip_distance="${NB_MAX_TRIP_DISTANCE}" -f "${GIT_ROOT}"/sql/connectivity/reachable_roads_low_stress_calc.sql
psql -v thread_num=8 -v thread_no=3 -v nb_max_trip_distance="${NB_MAX_TRIP_DISTANCE}" -f "${GIT_ROOT}"/sql/connectivity/reachable_roads_low_stress_calc.sql
psql -v thread_num=8 -v thread_no=4 -v nb_max_trip_distance="${NB_MAX_TRIP_DISTANCE}" -f "${GIT_ROOT}"/sql/connectivity/reachable_roads_low_stress_calc.sql
psql -v thread_num=8 -v thread_no=5 -v nb_max_trip_distance="${NB_MAX_TRIP_DISTANCE}" -f "${GIT_ROOT}"/sql/connectivity/reachable_roads_low_stress_calc.sql
psql -v thread_num=8 -v thread_no=6 -v nb_max_trip_distance="${NB_MAX_TRIP_DISTANCE}" -f "${GIT_ROOT}"/sql/connectivity/reachable_roads_low_stress_calc.sql
psql -v thread_num=8 -v thread_no=7 -v nb_max_trip_distance="${NB_MAX_TRIP_DISTANCE}" -f "${GIT_ROOT}"/sql/connectivity/reachable_roads_low_stress_calc.sql

time psql -f "${GIT_ROOT}"/sql/connectivity/reachable_roads_low_stress_cleanup.sql

echo "CONNECTIVITY: Connected census blocks"
time psql -v nb_max_trip_distance="${NB_MAX_TRIP_DISTANCE}" \
  -v nb_output_srid="${NB_OUTPUT_SRID}" \
  -f "${GIT_ROOT}"/sql/connectivity/connected_census_blocks.sql

# rgreinho: crashes with
#    psql:/Users/rgreinhofer/projects/rgreinho/modular-bna/sql/connectivity/access_population.sql:84: ERROR:  syntax error at or near ":"
#    LINE 6:     WHEN pop_high_stress = pop_low_stress THEN: max_score
echo "METRICS: Access: population"
time psql -v max_score=1 \
  -v step1=0.03 \
  -v score1=0.1 \
  -v step2=0.2 \
  -v score2=0.4 \
  -v step3=0.5 \
  -v score3=0.8 \
  -f "${GIT_ROOT}"/sql/connectivity/access_population.sql

if [ "$RUN_IMPORT_JOBS" = "1" ]; then
  echo "METRICS: Access: jobs"
  time psql -f "${GIT_ROOT}"/sql/connectivity/census_block_jobs.sql

  time psql -v max_score=1 \
    -v step1=0.03 \
    -v score1=0.1 \
    -v step2=0.2 \
    -v score2=0.4 \
    -v step3=0.5 \
    -v score3=0.8 \
    -f "${GIT_ROOT}"/sql/connectivity/access_jobs.sql
fi

echo "METRICS: Destinations"
time psql -v nb_output_srid="${NB_OUTPUT_SRID}" \
  -v cluster_tolerance="${TOLERANCE_COLLEGES}" \
  -f "${GIT_ROOT}"/sql/connectivity/destinations/colleges.sql

time psql -v nb_output_srid="${NB_OUTPUT_SRID}" \
  -v cluster_tolerance="${TOLERANCE_COMM_CTR}" \
  -f "${GIT_ROOT}"/sql/connectivity/destinations/community_centers.sql

time psql -v nb_output_srid="${NB_OUTPUT_SRID}" \
  -v cluster_tolerance="${TOLERANCE_DOCTORS}" \
  -f "${GIT_ROOT}"/sql/connectivity/destinations/doctors.sql

time psql -v nb_output_srid="${NB_OUTPUT_SRID}" \
  -v cluster_tolerance="${TOLERANCE_DENTISTS}" \
  -f "${GIT_ROOT}"/sql/connectivity/destinations/dentists.sql

time psql -v nb_output_srid="${NB_OUTPUT_SRID}" \
  -v cluster_tolerance="${TOLERANCE_HOSPITALS}" \
  -f "${GIT_ROOT}"/sql/connectivity/destinations/hospitals.sql

time psql -v nb_output_srid="${NB_OUTPUT_SRID}" \
  -v cluster_tolerance="${TOLERANCE_PHARMACIES}" \
  -f "${GIT_ROOT}"/sql/connectivity/destinations/pharmacies.sql

time psql -v nb_output_srid="${NB_OUTPUT_SRID}" \
  -v cluster_tolerance="${TOLERANCE_PARKS}" \
  -f "${GIT_ROOT}"/sql/connectivity/destinations/parks.sql

time psql -v nb_output_srid="${NB_OUTPUT_SRID}" \
  -v cluster_tolerance="${TOLERANCE_RETAIL}" \
  -f "${GIT_ROOT}"/sql/connectivity/destinations/retail.sql

time psql -v nb_output_srid="${NB_OUTPUT_SRID}" \
  -f "${GIT_ROOT}"/sql/connectivity/destinations/schools.sql

time psql -v nb_output_srid="${NB_OUTPUT_SRID}" \
  -f "${GIT_ROOT}"/sql/connectivity/destinations/social_services.sql

time psql -v nb_output_srid="${NB_OUTPUT_SRID}" \
  -f "${GIT_ROOT}"/sql/connectivity/destinations/supermarkets.sql

time psql -v nb_output_srid="${NB_OUTPUT_SRID}" \
  -v cluster_tolerance="${TOLERANCE_TRANSIT}" \
  -f "${GIT_ROOT}"/sql/connectivity/destinations/transit.sql

time psql -v nb_output_srid="${NB_OUTPUT_SRID}" \
  -v cluster_tolerance="${TOLERANCE_UNIVERSITIES}" \
  -f "${GIT_ROOT}"/sql/connectivity/destinations/universities.sql

echo "METRICS: Access: colleges"
time psql -v first=0.7 \
  -v second=0 \
  -v third=0 \
  -v max_score=1 \
  -f "${GIT_ROOT}"/sql/connectivity/access_colleges.sql

time psql -v first=0.4 \
  -v second=0.2 \
  -v third=0.1 \
  -v max_score=1 \
  -f "${GIT_ROOT}"/sql/connectivity/access_community_centers.sql

time psql -v first=0.4 \
  -v second=0.2 \
  -v third=0.1 \
  -v max_score=1 \
  -f "${GIT_ROOT}"/sql/connectivity/access_doctors.sql

time psql -v first=0.4 \
  -v second=0.2 \
  -v third=0.1 \
  -v max_score=1 \
  -f "${GIT_ROOT}"/sql/connectivity/access_dentists.sql

time psql -v first=0.7 \
  -v second=0 \
  -v third=0 \
  -v max_score=1 \
  -f "${GIT_ROOT}"/sql/connectivity/access_hospitals.sql

time psql -v first=0.4 \
  -v second=0.2 \
  -v third=0.1 \
  -v max_score=1 \
  -f "${GIT_ROOT}"/sql/connectivity/access_pharmacies.sql

time psql -v first=0.3 \
  -v second=0.2 \
  -v third=0.2 \
  -v max_score=1 \
  -f "${GIT_ROOT}"/sql/connectivity/access_parks.sql

time psql -v first=0.4 \
  -v second=0.2 \
  -v third=0.1 \
  -v max_score=1 \
  -f "${GIT_ROOT}"/sql/connectivity/access_retail.sql

time psql -v first=0.3 \
  -v second=0.2 \
  -v third=0.2 \
  -v max_score=1 \
  -f "${GIT_ROOT}"/sql/connectivity/access_schools.sql

time psql -v first=0.7 \
  -v second=0 \
  -v third=0 \
  -v max_score=1 \
  -f "${GIT_ROOT}"/sql/connectivity/access_social_services.sql

time psql -v first=0.6 \
  -v second=0.2 \
  -v third=0 \
  -v max_score=1 \
  -f "${GIT_ROOT}"/sql/connectivity/access_supermarkets.sql

time psql -v first=0.7 \
  -v second=0.2 \
  -v third=0 \
  -v max_score=1 \
  -v min_path_length="${MIN_PATH_LENGTH}" \
  -v min_bbox_length="${MIN_PATH_BBOX}" \
  -f "${GIT_ROOT}"/sql/connectivity/access_trails.sql

time psql -v first=0.6 \
  -v second=0 \
  -v third=0 \
  -v max_score=1 \
  -f "${GIT_ROOT}"/sql/connectivity/access_transit.sql

time psql -v first=0.7 \
  -v second=0 \
  -v third=0 \
  -v max_score=1 \
  -f "${GIT_ROOT}"/sql/connectivity/access_universities.sql

time psql -v total="${SCORE_TOTAL}" \
  -v people="${SCORE_PEOPLE}" \
  -v opportunity="${SCORE_OPPORTUNITY}" \
  -v core_services="${SCORE_CORESVCS}" \
  -v retail="${SCORE_RETAIL}" \
  -v recreation="${SCORE_RECREATION}" \
  -v transit="${SCORE_TRANSIT}" \
  -f "${GIT_ROOT}"/sql/connectivity/access_overall.sql

time psql -f "${GIT_ROOT}"/sql/connectivity/score_inputs.sql

echo "METRICS: Overall scores"
time psql -v total="${SCORE_TOTAL}" \
  -v people="${SCORE_PEOPLE}" \
  -v opportunity="${SCORE_OPPORTUNITY}" \
  -v core_services="${SCORE_CORESVCS}" \
  -v retail="${SCORE_RETAIL}" \
  -v recreation="${SCORE_RECREATION}" \
  -v transit="${SCORE_TRANSIT}" \
  -f "${GIT_ROOT}"/sql/connectivity/overall_scores.sql
