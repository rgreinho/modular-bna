"""Functions related to the BNA."""
import os
import pathlib
import shutil
import subprocess
import typing
import unicodedata

import pandas as pd
from brokenspoke_analyzer import cli as bna_cli
from brokenspoke_analyzer.core import (
    analysis,
    processhelper,
)

from modular_bna import cli

CONTAINER_NAME = "brokenspoke_analyzer"
DOCKER_IMAGE = "azavea/pfb-network-connectivity:0.18.0"


def prepare_sample_folder(
    city: str, state: str
) -> typing.Tuple[os.PathLike, os.PathLike]:
    """Prepare the directory where to put the input files and results."""
    output_dir = pathlib.Path(f"tests/samples/{city}-{state}")
    shutil.rmtree(output_dir, ignore_errors=True)
    modular_bna_output_dir = output_dir / "modular-bna"
    modular_bna_output_dir.mkdir(parents=True, exist_ok=True)
    return (output_dir, modular_bna_output_dir)


def derive_state_info(state: str) -> typing.Tuple[str, str, str]:
    """
    Derive some city information.

    Examples:
        >>> assert ("TX", "48", "1") == derive_state_info("texas")
        >>> assert ("ZZ", 0, "0") == derive_state_info("spain")
    """
    try:
        run_import_jobs = "1"
        state_abbrev, state_fips = analysis.state_info(state)
    except ValueError:
        run_import_jobs = "0"
        state_abbrev, state_fips = (
            processhelper.NON_US_STATE_ABBREV,
            processhelper.NON_US_STATE_FIPS,
        )
    return (state_abbrev, state_fips, run_import_jobs)


def prepare_environment(
    city: str,
    state: str,
    country: str,
    city_fips: str,
    state_fips: str,
    state_abbrev: str,
    run_import_jobs: str,
) -> typing.Mapping[str, str]:
    """
    Prepare the environment variables required by the modular BNA.

    Example:
        >>> d = prepare_environment(
        >>>     "washington", "district of columbia", "usa", "1150000", "11", "DC", "1"
        >>> )
        >>> assert d == {
        >>>    "BNA_CITY": "washington",
        >>>    "BNA_FULL_STATE": "district of columbia",
        >>>    "BNA_CITY_FIPS": "1150000",
        >>>    "BNA_COUNTRY": "usa",
        >>>    "BNA_SHORT_STATE": "dc",
        >>>    "BNA_STATE_FIPS": "11",
        >>>    "RUN_IMPORT_JOBS": "1",
        >>>    "NB_COUNTRY": "usa",
        >>>    "PFB_CITY_FIPS": "1150000",
        >>>    "PFB_STATE_FIPS": "11",
        >>>    "PFB_STATE": "dc",
        >>> }
    """
    normalized_city_fips = f"{city_fips:07}"
    normalized_state = state_abbrev.lower()
    normalized_state_fips = str(state_fips)
    return {
        "BNA_CITY": city,
        "BNA_FULL_STATE": state,
        "BNA_CITY_FIPS": normalized_city_fips,
        "BNA_COUNTRY": country,
        "BNA_SHORT_STATE": normalized_state,
        "BNA_STATE_FIPS": normalized_state_fips,
        "RUN_IMPORT_JOBS": run_import_jobs,
        "NB_COUNTRY": country,
        "PFB_CITY_FIPS": normalized_city_fips,
        "PFB_STATE_FIPS": normalized_state_fips,
        "PFB_STATE": normalized_state,
    }


async def brokenspoke_analyzer_run_prepare(
    city: str,
    state: str,
    country: str,
    output_dir: os.PathLike,
    speed_limit: int = 50,
):
    """Run the prepare command of the brokenspoke-analyzer."""

    return await bna_cli.prepare_(
        country,
        state,
        city,
        output_dir,
        speed_limit=speed_limit,
        block_size=500,
        block_population=100,
    )


def brokenspoke_analyzer_run_analyze(
    state_abbrev: str,
    state_fips: str,
    city_shp: os.PathLike,
    pfb_osm_file: os.PathLike,
    output_dir: os.PathLike,
):
    """Run the analyze command of the brokenspoke-analyzer."""
    bna_cli.analyze_(
        state_abbrev,
        state_fips,
        city_shp,
        pfb_osm_file,
        output_dir,
        docker_image=DOCKER_IMAGE,
        container_name=CONTAINER_NAME,
    )


async def brokenspoke_analyzer_run_n_cleanup(
    city: str,
    state: str,
    country: str,
    output_dir: os.PathLike,
    speed_limit: int = 50,
) -> None:
    """
    Run the Brokenspoke analyzer.

    Clean up the container in case of failure.
    """

    try:
        await bna_cli.prepare_and_run(
            country,
            state,
            city,
            output_dir.absolute(),
            docker_image=DOCKER_IMAGE,
            speed_limit=speed_limit,
            block_size=500,
            block_population=100,
            container_name=CONTAINER_NAME,
        )
    finally:
        subprocess.run(["docker", "stop", CONTAINER_NAME])


async def modular_bna_run_n_clean_up(
    city: str, state: str, country: str, city_fips: str, prepare: bool = False
) -> None:
    """
    Run the modular BNA.

    Clean up the docker compose environment at the end of the process or in case
    of failure.
    """
    try:
        try:
            subprocess.run(["docker-compose", "up", "-d"], check=True)
        except Exception:
            subprocess.run(["docker", "compose", "up", "-d"], check=True)
        subprocess.run("until pg_isready ; do sleep 5 ; done", shell=True, check=True)
        await cli.run_(city, state, country, city_fips, prepare)
    finally:
        try:
            subprocess.run(["docker-compose", "rm", "-sfv"], check=True)
        except Exception:
            subprocess.run(["docker", "compose", "rm", "-sfv"], check=True)
        subprocess.run(["docker", "volume", "rm", "-f", "modular-bna_postgres"])


def delta_df(output_dir: os.PathLike, modular_bna_output_dir: os.PathLike):
    """Prepare the dataframe with the deltas."""
    modular_bna_df = pd.read_csv(
        modular_bna_output_dir / "neighborhood_overall_scores.csv",
        usecols=["score_id", "score_normalized"],
    )
    modular_bna_df = modular_bna_df.rename(columns={"score_normalized": "modular"})
    original_csv = list(
        output_dir.glob("local-analysis-*/neighborhood_overall_scores.csv")
    )[0]
    original_bna_df = pd.read_csv(
        original_csv, usecols=["score_id", "score_normalized"]
    )
    original_bna_df = original_bna_df.rename(columns={"score_normalized": "original"})
    df = pd.concat([modular_bna_df, original_bna_df.original.to_frame()], axis=1)

    # Drop the total mile column for now, until we know how to validate them.
    df = df.drop(df[df.score_id == "total_miles_low_stress"].index)
    df = df.drop(df[df.score_id == "total_miles_high_stress"].index)
    df = df.dropna()

    # Compute the deltas.
    df["delta"] = (df["modular"] * 100).astype(int) - (df["original"] * 100).astype(int)

    return df


async def compare(city: str, state: str, country: str, city_fips: str) -> pd.DataFrame:
    """Compare the results of the original BNA versus the modular BNA."""
    # Prepare the directories.
    output_dir, modular_bna_output_dir = prepare_sample_folder(city, state)

    # Compute the results with the Brokenspoke-analyzer.
    # This will prepare the input data for the modular-bna at the same time,
    # therefore reducing the processing time and saving disk space.
    await brokenspoke_analyzer_run_n_cleanup(city, state, country, output_dir)

    # Compute the results with the modular BNA.
    await modular_bna_run_n_clean_up(city, state, country, city_fips, False)

    # Combine the results.
    df = delta_df(output_dir, modular_bna_output_dir)

    # Export for human consumption.
    df.to_csv(output_dir / f"compare-{city}-{state}.csv")

    return df


# Note(rgreinho): This should be part of the Brokenspoke-analyzer.
def sanitize_value(value: str) -> str:
    """
    Sanitize a string for consumption by the BNA scripts.

    Examples:
        >>> sanitize_value("Chambéry")
        chambery
        >>> sanitize_value("Cañon city")
        canon-city
    """
    v = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode("utf-8")
    v = v.lower()
    v = v.replace(" ", "-")
    v = v.replace(".", "")
    return v
