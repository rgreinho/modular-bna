src_dir := "brokenspoke_analyzer"

#  Lint python files.
lint-python:
    poetry run isort --check {{ src_dir }}
    poetry run black --check {{ src_dir }}
    poetry run ruff check {{ src_dir }}

# Format python files.
fmt-python:
    poetry run isort {{ src_dir }}
    poetry run black {{ src_dir }}
    poetry run ruff check --fix {{ src_dir }}
