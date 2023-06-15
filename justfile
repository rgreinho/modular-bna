set dotenv-load

# Define variables.
script_dir := "scripts"
sql_dir := "sql"

# Meta task running ALL the CI tasks at onces.
ci: lint

# Meta task running all the linters at once.
lint: lint-bash lint-python lint-sql

# Lint bash files.
lint-bash:
    shellcheck {{ script_dir }}/*.sh

#  Lint python files.
lint-python:
    poetry run isort --check {{ script_dir }}
    poetry run black --check {{ script_dir }}
    poetry run ruff check {{ script_dir }}

# Lint SQL files.
lint-sql:
    poetry run sqlfluff lint {{ sql_dir }}

# Meta tasks running all formatters at once.
fmt: fmt-bash fmt-python fmt-sql

# Format bash files.
fmt-bash:
    shfmt --list -write {{ script_dir }}

# Format python files.
fmt-python:
    poetry run isort {{ script_dir }}
    poetry run black {{ script_dir }}
    poetry run ruff check --fix {{ script_dir }}


# Format SQL files.
fmt-sql:
    poetry run sqlfluff fix --force {{ sql_dir }}

# Build the test Docker image.
docker-build:
   docker buildx build -t bna:remy .

# Run the Docker image.
docker-run:
    docker run \
      --rm \
      --name bna \
      -e PGUSER=gis \
      -e PGPASSWORD= \
      -e PGHOST=localhost \
      -e PGDATABASE=pfb \
      bna:remy

bna-prepare:
    ./scripts/01-setup_database.sh

bna-import-provincetown-massachusetts:
    NB_TEMPDIR="${PWD}/test/data" PFB_STATE_FIPS=25 NB_INPUT_SRID=4236 NB_OUTPUT_SRID=2163 NB_BOUNDARY_FILE="${PWD}/test/data/provincetown-massachusetts.shp" NB_COUNTRY=USA ./scripts/21-import_neighborhood.sh
    NB_TEMPDIR="${PWD}/test/data" PFB_STATE=ma CENSUS_YEAR=2019 ./scripts/22-import_jobs.sh
    NB_TEMPDIR="${PWD}/test/data" PFB_STATE_FIPS=25 PFB_CITY_FIPS=555535 ./scripts/23-import_osm.sh "${PWD}/test/data/provincetown-massachusetts.osm"

bna-compute-provincetown-massachusetts:
    NB_OUTPUT_SRID=2163 ./scripts/30-compute-features.sh
    STATE_DEFAULT=30 CITY_DEFAULT=NULL ./scripts/31-compute-stress.sh
    RUN_IMPORT_JOBS=1 ./scripts/32-compute-run-connectivity.sh

bna-export-provincetown-massachusetts:
    rm -fr ./output
    mkdir ./output
    ./scripts/40-export-export_connectivity.sh output

bna-run: bna-prepare bna-import-provincetown-massachusetts bna-compute-provincetown-massachusetts bna-export-provincetown-massachusetts
