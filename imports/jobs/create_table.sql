CREATE TABLE IF NOT EXISTS "state_od_main_JT00" (
    w_geocode varchar(15),
    h_geocode varchar(15),
    "S000" integer,
    "SA01" integer,
    "SA02" integer,
    "SA03" integer,
    "SE01" integer,
    "SE02" integer,
    "SE03" integer,
    "SI01" integer,
    "SI02" integer,
    "SI03" integer,
    createdate varchar(32)
);
\copy state_od_main_JT00 FROM 'data/census_jobs.csv' DELIMITER ',' CSV HEADER;
