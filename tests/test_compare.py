"""Compare the overall scores between the original BNA and the modular BNA."""

import pytest
from dotenv import load_dotenv

from modular_bna import bna

# Since we multiply the BNA score by 100 to get integer numbers and avoiding
# floating number operations, the delta must also be multiplied by 100.
# As a result, a delta of 10 means 0.1%.
DELTA = 10


@pytest.mark.usa
@pytest.mark.xs
@pytest.mark.asyncio
async def test_provincetown_ma():
    """Compare the results for the city of Provincetown, MA."""
    await assert_compare("provincetown", "massachusetts", "usa", "555535")


@pytest.mark.usa
@pytest.mark.l
@pytest.mark.asyncio
@pytest.mark.skip(
    reason="generates completely different results, like 2 different cities"
)
async def test_flagstaff_az():
    """Compare the results for the city of Flagstaff, AZ."""
    await assert_compare("flagstaff", "arizona", "usa", "0423620")


@pytest.mark.spain
@pytest.mark.europe
@pytest.mark.asyncio
async def test_valencia_spain():
    """Compare the results for the city of Valencia, Spain."""
    await assert_compare("valencia", "valencia", "spain", "0")


@pytest.mark.usa
@pytest.mark.xs
@pytest.mark.asyncio
async def test_santa_rosa_nm():
    """Compare the results for the city of Santa Rosa, NM."""
    await assert_compare("santa rosa", "new mexico", "usa", "3570670")


@pytest.mark.usa
@pytest.mark.xs
@pytest.mark.asyncio
async def test_crested_butte_co():
    """Compare the results for the city of Crested Butte, CO."""
    await assert_compare("crested butte", "colorado", "usa", "818310")


@pytest.mark.usa
@pytest.mark.xxl
@pytest.mark.asyncio
@pytest.mark.skip(reason="takes about a day to complete")
async def test_washington_dc():
    """Compare the results for the city of Washington, DC."""
    await assert_compare("washington", "district of columbia", "usa", "1150000")


async def assert_compare(city: str, state: str, country: str, city_fips: str) -> None:
    # Load the environment variables.
    load_dotenv()

    # Run the comparison.
    df = await bna.compare(city, state, country, city_fips)

    # Assert the deltas are within range.
    assert all(df.delta.apply(lambda x: -DELTA <= x <= DELTA))
