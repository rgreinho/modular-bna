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
