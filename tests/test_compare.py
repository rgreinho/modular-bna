"""Compare the overall scores between the original BNA and the modular BNA."""

import pytest
from dotenv import load_dotenv
from loguru import logger

from modular_bna.core import bna

# Since we multiply the BNA score by 100 to get integer numbers and avoiding
# floating number operations, the delta must also be multiplied by 100.
# As a result, a delta of 1000 means 10%.
# 10000 means the delta is disabled until we figure out why the delta is so big
# in some cases
DELTA = 10


@pytest.mark.parametrize(
    "city,state,country,city_fips",
    [
        pytest.param(
            "provincetown",
            "massachusetts",
            "usa",
            "555535",
            id="provincetown-ma-usa",
            marks=[pytest.mark.xs, pytest.mark.usa, pytest.mark.main],
        ),
        pytest.param(
            "santa rosa",
            "new mexico",
            "usa",
            "3570670",
            id="santa-rosa-nm-usa",
            marks=[pytest.mark.xs, pytest.mark.usa, pytest.mark.main],
        ),
        pytest.param(
            "crested butte",
            "colorado",
            "usa",
            "818310",
            id="crested-butte-co-usa",
            marks=[pytest.mark.xs, pytest.mark.usa, pytest.mark.main],
        ),
        pytest.param(
            "ancienne-lorette",
            "québec",
            "canada",
            "0",
            id="ancienne-lorette-quebec-canada",
            marks=[pytest.mark.xs, pytest.mark.canada, pytest.mark.main],
        ),
        pytest.param(
            "st. louis park",
            "minnesota",
            "usa",
            "2757220",
            id="st-louis-park-mn-usa",
            marks=[pytest.mark.m, pytest.mark.usa, pytest.mark.main],
        ),
        pytest.param(
            "arcata",
            "california",
            "usa",
            "602476",
            id="arcata-ca-usa",
            marks=[pytest.mark.m, pytest.mark.usa, pytest.mark.main],
        ),
        pytest.param(
            "rehoboth beach",
            "delaware",
            "usa",
            "1060290",
            id="rehoboth-beach-de-usa",
            marks=[pytest.mark.xs, pytest.mark.usa, pytest.mark.main],
        ),
        pytest.param(
            "orange",
            "new south wales",
            "australia",
            "0",
            id="orange-nsw-australia",
            marks=[pytest.mark.xs, pytest.mark.australia, pytest.mark.main],
        ),
        pytest.param(
            "cañon city",
            "colorado",
            "usa",
            "0811810",
            id="canon-city-co-usa",
            marks=[pytest.mark.s, pytest.mark.usa, pytest.mark.main],
        ),
        pytest.param(
            "valencia",
            "valencia",
            "spain",
            "0",
            id="valencia-valencia-spain",
            marks=[pytest.mark.xl, pytest.mark.spain, pytest.mark.europe],
        ),
        pytest.param(
            "chambéry",
            "savoie",
            "france",
            "0",
            id="chambery-savoie-france",
            marks=[pytest.mark.s, pytest.mark.france, pytest.mark.main],
        ),
        pytest.param(
            "flagstaff",
            "arizona",
            "usa",
            "0423620",
            id="flagstaff-az-usa",
            marks=[
                pytest.mark.m,
                pytest.mark.usa,
            ],
        ),
        pytest.param(
            "washington",
            "district of columbia",
            "usa",
            "1150000",
            id="washington-dc-usa",
            marks=[
                pytest.mark.xxl,
                pytest.mark.usa,
                pytest.mark.skip(reason="takes about a day to complete"),
            ],
        ),
    ],
)
@pytest.mark.asyncio
async def test_compare(city: str, state: str, country: str, city_fips: str):
    # Set the logging level.
    logger.level("DEBUG")

    # Load the environment variables.
    load_dotenv()

    # Run the comparison.
    df = await bna.compare(city, state, country, city_fips)

    # Assert the deltas are within range.
    assert all(df.delta.apply(lambda x: -DELTA <= x <= DELTA))
