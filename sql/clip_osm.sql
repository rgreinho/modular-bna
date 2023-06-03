----------------------------------------
-- INPUTS
-- location: neighborhood
-- :nb_boundary_buffer psql var must be set before running this script,
--      e.g. psql -v nb_boundary_buffer=1000 -f clip_osm.sql
----------------------------------------


DELETE FROM neighborhood_ways AS ways
USING neighborhood_boundary AS boundary
WHERE NOT ST_DWITHIN(ways.geom, boundary.geom,: nb_boundary_buffer);

DELETE FROM neighborhood_ways_intersections AS intersections
USING neighborhood_boundary AS boundary
WHERE NOT ST_DWITHIN(intersections.geom, boundary.geom,: nb_boundary_buffer);

DELETE FROM neighborhood_osm_full_line AS lines
USING neighborhood_boundary AS boundary
WHERE NOT ST_DWITHIN(lines.way, boundary.geom,: nb_boundary_buffer);

DELETE FROM neighborhood_osm_full_point AS points
USING neighborhood_boundary AS boundary
WHERE NOT ST_DWITHIN(points.way, boundary.geom,: nb_boundary_buffer);

DELETE FROM neighborhood_osm_full_polygon AS polygons
USING neighborhood_boundary AS boundary
WHERE NOT ST_DWITHIN(polygons.way, boundary.geom,: nb_boundary_buffer);

DELETE FROM neighborhood_osm_full_roads AS roads
USING neighborhood_boundary AS boundary
WHERE NOT ST_DWITHIN(roads.way, boundary.geom,: nb_boundary_buffer);
