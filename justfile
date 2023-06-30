set dotenv-load

# Define variables.
script_dir := "scripts"
modular_bna_dir := "modular_bna"
sql_dir := "sql"

# Meta task running ALL the CI tasks at onces.
ci: lint

# Meta task running all the linters at once.
lint: lint-bash lint-md lint-python lint-sql

# Lint bash files.
lint-bash:
    shellcheck {{ script_dir }}/*.sh

# Lint markown files.
lint-md:
    npx --yes markdownlint-cli2 "**/*.md" "#.venv"

#  Lint python files.
lint-python:
    poetry run isort --check {{ script_dir }}
    poetry run black --check {{ script_dir }}
    poetry run ruff check {{ script_dir }}
    poetry run isort --check {{ modular_bna_dir }}
    poetry run black --check {{ modular_bna_dir }}
    poetry run ruff check {{ modular_bna_dir }}

# Lint SQL files. Temporarily disabled.
lint-sql:
    echo "Lint disabled."
    # poetry run sqlfluff lint {{ sql_dir }}

# Meta tasks running all formatters at once.
fmt: fmt-bash fmt-md fmt-python fmt-sql

# Format bash files.
fmt-bash:
    shfmt --list -write {{ script_dir }}

# Format markdown files.
fmt-md:
    npx --yes prettier --write --prose-wrap always **/*.md

# Format python files.
fmt-python:
    poetry run isort {{ script_dir }}
    poetry run black {{ script_dir }}
    poetry run ruff check --fix {{ script_dir }}
    poetry run isort {{ modular_bna_dir }}
    poetry run black {{ modular_bna_dir }}
    poetry run ruff check --fix {{ modular_bna_dir }}

# Format SQL files. Temporarily disabled.
fmt-sql:
    echo "Formatting disabled."
    # poetry run sqlfluff fix --force {{ sql_dir }}

# Build the test Docker image.
docker-build:
   docker buildx build -t bna:mechanics .

# Run the doctests.
doctest:
    python -m xdoctest {{ modular_bna_dir }}

# Test all the cities.
test:
  poetry run pytest -v

# Test only the US cities.
test-usa:
  poetry run pytest -v -m usa

# Test only the XS cities.
test-xs:
  poetry run pytest -v -m xs
