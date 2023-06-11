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
    NB_TEMPDIR="${PWD}/test/data" ./scripts/23-import_osm.sh "${PWD}/test/data/provincetown-massachusetts.osm"

setup-flagstaff:
    mkdir -p test/usa-az-flagstaff \
    && cd test/usa-az-flagstaff \
    && export PFB_STATE=az CENSUS_YEAR=2019 \
    && curl -L -o - http://lehd.ces.census.gov/data/lodes/LODES7/${PFB_STATE}/od/${PFB_STATE}_od_main_JT00_${CENSUS_YEAR}.csv.gz | gunzip > ${PFB_STATE}_od_main_JT00_${CENSUS_YEAR}.csv \
    && curl -L -o - http://lehd.ces.census.gov/data/lodes/LODES7/${PFB_STATE}/od/${PFB_STATE}_od_aux_JT00_${CENSUS_YEAR}.csv.gz | gunzip > ${PFB_STATE}_od_aux_JT00_${CENSUS_YEAR}.csv \
    && curl -LO https://s3.amazonaws.com/pfb-public-documents/censuswaterblocks.zip \
    && unzip censuswaterblocks.zip \
    && rm -f censuswaterblocks.zip \
    && curl -LO http://www2.census.gov/geo/tiger/TIGER2010BLKPOPHU/tabblock2010_04_pophu.zip \
    && unzip tabblock2010_04_pophu.zip \
    && rm -f tabblock2010_04_pophu.zip \
    && for f in tabblock2010_04_pophu.*; do mv "$f" "${f/tabblock2010_04_pophu/population}"; done \
