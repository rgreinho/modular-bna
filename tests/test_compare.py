"""Compare the overall scores between the original BNA and the modular BNA."""
import os
import pathlib
import shutil
import subprocess

import pandas as pd
import pytest
from brokenspoke_analyzer import cli
from brokenspoke_analyzer.core import (
    analysis,
    processhelper,
)
from dotenv import load_dotenv

# Since we multiply the BNA score by 100 to get integer numbers and avoiding
# floating number operations, the delta must also be multiplied by 100.
# As a result, a delta of 10 means 0.1%.
DELTA = 10


@pytest.mark.usa
@pytest.mark.xs
@pytest.mark.asyncio
async def test_provincetown_ma():
    """Compare the results for the city of Provincetown, MA."""
    await compare("usa", "massachusetts", "provincetown", "555535")


@pytest.mark.usa
@pytest.mark.l
@pytest.mark.asyncio
@pytest.mark.skip(
    reason="generates completely different results, like 2 different cities"
)
async def test_flagstaff_az():
    """Compare the results for the city of Flagstaff, AZ."""
    await compare("usa", "arizona", "flagstaff", "0")


@pytest.mark.spain
@pytest.mark.europe
@pytest.mark.asyncio
async def test_valencia_spain():
    """Compare the results for the city of Valencia, Spain."""
    await compare("spain", "valencia", "valencia", "0")


@pytest.mark.usa
@pytest.mark.xs
@pytest.mark.asyncio
async def test_santa_rosa_nm():
    """Compare the results for the city of Santa Rosa, NM."""
    await compare("usa", "new mexico", "santa rosa", "0")


@pytest.mark.usa
@pytest.mark.xs
@pytest.mark.asyncio
async def test_crested_butte_co():
    """Compare the results for the city of Crested Butte, CO."""
    await compare("usa", "colorado", "crested butte", "0")


@pytest.mark.usa
@pytest.mark.l
@pytest.mark.asyncio
async def test_washington_dc():
    """Compare the results for the city of Washington, DC."""
    await compare("usa", "district of columbia", "washington", "0")


async def compare(country: str, state: str, city: str, city_fips: str) -> None:
    # Load the environment variables.
    load_dotenv()

    # Prepare the directories.
    output_dir = pathlib.Path(f"tests/samples/{city}-{state}")
    shutil.rmtree(output_dir, ignore_errors=True)
    modular_bna_output_dir = output_dir / "modular-bna"
    modular_bna_output_dir.mkdir(parents=True, exist_ok=True)

    # Derive some city information.
    try:
        run_import_jobs = "1"
        if state:
            state_abbrev, state_fips = analysis.state_info(state)
        else:
            state_abbrev, state_fips = analysis.state_info(country)
    except ValueError:
        run_import_jobs = "0"
        state_abbrev, state_fips = (
            processhelper.NON_US_STATE_ABBREV,
            processhelper.NON_US_STATE_FIPS,
        )

    # Compute the results with the Brokenspoke-analyzer.
    # This will prepare the input data for the modular-bna at the same time,
    # therefore reducing the processing time and saving disk space.
    await cli.prepare_and_run(
        country,
        state,
        city,
        output_dir.absolute(),
        docker_image="azavea/pfb-network-connectivity:0.18.0",
        speed_limit=50,
        block_size=500,
        block_population=100,
    )

    # Compute the results with the modular BNA.
    try:
        env = os.environ.update(
            {
                "BNA_CITY": city,
                "BNA_FULL_STATE": state,
                "BNA_CITY_FIPS": city_fips,
                "BNA_COUNTRY": country,
                "BNA_SHORT_STATE": state_abbrev.lower(),
                "BNA_STATE_FIPS": str(state_fips),
                "RUN_IMPORT_JOBS": run_import_jobs,
            }
        )
        try:
            subprocess.run(["docker-compose", "up", "-d"])
        except:
            subprocess.run(["docker", "compose", "up", "-d"])
        subprocess.run("until pg_isready ; do sleep 5 ; done", shell=True, check=True)
        subprocess.run(
            ["tests/scripts/run-analysis.sh"], shell=True, check=True, env=env
        )
    finally:
        try:
            subprocess.run(["docker-compose", "rm", "-sfv"])
        except:
            subprocess.run(["docker", "compose", "rm", "-sfv"])
        subprocess.run(["docker", "volume", "rm", "-f", "modular-bna_postgres"])

    # Combine the results.
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

    # Export for human consumption.
    df.to_csv(output_dir / f"compare-{city}-{state}.csv")

    # Assert the deltas are within range.
    assert all(df.delta.apply(lambda x: -DELTA <= x <= DELTA))
