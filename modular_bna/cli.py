import asyncio
import logging
import os
import pathlib
import shutil
import subprocess
import sys

import typer
from dotenv import load_dotenv
from loguru import logger
from typing_extensions import Annotated

from modular_bna.core import bna


def callback(verbose: int = typer.Option(0, "--verbose", "-v", count=True)):
    """Define callback to configure global flags."""
    # Configure the logger.

    # Remove any predefined logger.
    logger.remove()

    # The log level gets adjusted by adding/removing `-v` flags:
    #   None    : Initial log level is WARNING.
    #   -v      : INFO
    #   -vv     : DEBUG
    #   -vvv    : TRACE
    initial_log_level = logging.WARNING
    log_format = (
        "<level>{time:YYYY-MM-DDTHH:mm:ssZZ} {level:.3} {name}:{line} {message}</level>"
    )
    log_level = max(initial_log_level - verbose * 10, 0)

    # Set the log colors.
    logger.level("ERROR", color="<red><bold>")
    logger.level("WARNING", color="<yellow>")
    logger.level("SUCCESS", color="<green>")
    logger.level("INFO", color="<cyan>")
    logger.level("DEBUG", color="<blue>")
    logger.level("TRACE", color="<magenta>")

    # Add the logger.
    logger.add(sys.stdout, format=log_format, level=log_level, colorize=True)

    # Store the logging state.
    appstate["verbose"] = verbose


# Create the CLI app.
app = typer.Typer(callback=callback)

# Create the CLI state.
appstate = {"verbose": 0}


# pylint: disable=too-many-arguments
@app.command()
def run(
    city: str,
    state: str,
    country: str,
    city_fips: str,
    prepare: Annotated[bool, typer.Option(help="Prepare input files")] = False,
):
    """Run an analysis with the modular-bna."""
    asyncio.run(run_(city, state, country, city_fips, prepare))


async def run_(
    city: str,
    state: str,
    country: str,
    city_fips: str,
    prepare: Annotated[bool, typer.Option(help="Prepare input files")] = False,
):
    """Run an analysis with the modular-bna."""
    # Load the environment variables.
    load_dotenv()

    # Prepare the directory structure.
    normalized_city_name = sanitize_name(f"{city}-{state}-{country}")
    print(f"{normalized_city_name=}")
    root = pathlib.Path(".")
    test_dir = root / "tests"
    script_dir = root / "scripts"
    sample_dir = test_dir / "samples"
    city_dir = sample_dir / f"{city}-{state}"
    output_dir = city_dir / "modular-bna"
    city_data_file = city_dir / normalized_city_name
    city_osm_file = city_data_file.with_suffix(".osm")
    city_boundary_file = city_data_file.with_suffix(".shp")

    # Derive some city information.
    st = state if state else country
    state_abbrev, state_fips, run_import_jobs = bna.derive_state_info(st)

    # Prepare the input files for the analysis.
    if prepare:
        await bna.brokenspoke_analyzer_run_prepare(city, state, country, city_dir)

    # Define the variables required by the original BNA scripts.
    debug = "1" if appstate["verbose"] else "0"
    bna_env = bna.prepare_environment(
        city, state, country, city_fips, state_fips, state_abbrev, run_import_jobs
    )
    bna_env["CENSUS_YEAR"] = "2019"
    bna_env["CITY_DEFAULT"] = "NULL"
    bna_env["NB_INPUT_SRID"] = "4236"
    bna_env["NB_OUTPUT_SRID"] = "2163"
    bna_env["STATE_DEFAULT"] = "30"
    bna_env["PFB_DEBUG"] = debug
    bna_env["NB_BOUNDARY_FILE"] = str(city_boundary_file.absolute())
    bna_env["NB_TEMPDIR"] = str(city_dir.absolute())
    logger.debug(f"{bna_env=}")
    os.environ.update(**bna_env)

    # Prepare.
    logger.info("Setup database")
    script = script_dir / "01-setup_database.sh"
    subprocess.run([str(script.absolute())], check=True)

    # # Import.
    logger.info("Import neighborhood")
    script = script.with_name("21-import_neighborhood.sh")
    subprocess.run([str(script.absolute())], check=True)
    if run_import_jobs == "1":
        logger.info("Import jobs")
        script = script.with_name("22-import_jobs.sh")
        subprocess.run([str(script.absolute())], check=True)
    logger.info("Import OSM")
    script = script.with_name("23-import_osm.sh")
    subprocess.run(
        [str(script), str(city_osm_file.absolute())],
        check=True,
    )

    # Compute.
    logger.info("Compute features")
    script = script.with_name("30-compute-features.sh")
    subprocess.run([str(script.absolute())], check=True)
    logger.info("Compute stress")
    script = script.with_name("31-compute-stress.sh")
    subprocess.run([str(script.absolute())], check=True)
    logger.info("Compute connectivity")
    script = script.with_name("32-compute-run-connectivity.sh")
    subprocess.run([str(script.absolute())], check=True)

    # Export.
    shutil.rmtree(output_dir, ignore_errors=True)
    output_dir.mkdir(parents=True, exist_ok=True)
    script = script.with_name("40-export-export_connectivity.sh")
    subprocess.run([str(script.absolute()), str(output_dir.absolute())], check=True)


def sanitize_name(value):
    n = bna.normalize_unicode_name(value)
    n = n.replace(" ", "-")
    n = n.replace(".", "")
    return n
