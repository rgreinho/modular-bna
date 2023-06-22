"""Compare the overall scores between the original BNA and the modular BNA."""
import os
import pathlib
import shutil
import subprocess

from brokenspoke_analyzer.core import analysis
from brokenspoke_analyzer import cli
from dotenv import load_dotenv
import pytest
import pandas as pd

DELTA = 0.05


@pytest.mark.asyncio
async def test_provincetown_ma():
    """Compare the results for the city of Provincetown, MA."""
    await compare("USA", "massachusetts", "provincetown", "555535")


async def compare(country, state, city, city_fips):
    # Load the environment variables.
    load_dotenv()

    # Prepare the directories.
    output_dir = pathlib.Path(f"tests/samples/{city}-{state}")
    shutil.rmtree(output_dir, ignore_errors=True)
    modular_bna_output_dir = output_dir / "modular-bna"
    modular_bna_output_dir.mkdir(parents=True, exist_ok=True)

    # Derive some city information.
    state_abbrev, state_fips = analysis.state_info(state)

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
    env = os.environ.update(
        {
            "BNA_CITY": city,
            "BNA_FULL_STATE": state,
            "BNA_CITY_FIPS": city_fips,
            "BNA_COUNTRY": country,
            "BNA_SHORT_STATE": state_abbrev,
            "BNA_STATE_FIPS": state_fips,
        }
    )
    subprocess.run(["docker-compose", "up", "-d"])
    subprocess.run("until pg_isready ; do sleep 5 ; done", shell=True, check=True)
    subprocess.run(["tests/scripts/run-analysis.sh"], shell=True, check=True, env=env)
    subprocess.run(["docker-compose", "rm", "-sfv"])
    subprocess.run(["docker", "volume", "rm", "modular-bna_postgres"])

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
    df["delta"] = df["modular"] - df["original"]

    # Export for human consumption.
    df.to_csv(output_dir / "compare.csv")

    # Assert the deltas are within range.
    assert all(df.delta.apply(lambda x: -DELTA <= x <= DELTA))
