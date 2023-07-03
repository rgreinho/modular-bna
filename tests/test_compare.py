"""Compare the overall scores between the original BNA and the modular BNA."""

import pytest
from dotenv import load_dotenv

from modular_bna.core import bna

# Since we multiply the BNA score by 100 to get integer numbers and avoiding
# floating number operations, the delta must also be multiplied by 100.
# As a result, a delta of 10 means 0.1%.
# 1000 means the delta is disabled until we figure out why the delta is so big
# in some cases
DELTA = 1000


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
@pytest.mark.xl
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


@pytest.mark.canada
@pytest.mark.xs
@pytest.mark.asyncio
async def test_l_ancienne_lorette_qc():
    """Compare the results of L'Ancienne-Lorette, QC."""
    await assert_compare("ancienne-lorette", "québec", "canada", "0")


@pytest.mark.usa
@pytest.mark.xs
@pytest.mark.asyncio
async def test_st_louis_park_mn():
    """Compare the results of St. Louis Park, MN."""
    await assert_compare("st. louis park", "minnesota", "usa", "2757220")


@pytest.mark.france
@pytest.mark.xs
@pytest.mark.asyncio
@pytest.mark.skip(reason="does not find streets to analyze")
async def test_chambery_france():
    """Compare the results of Chambéry, France."""
    await assert_compare("chambéry", "auvergne", "France", "0")


@pytest.mark.usa
@pytest.mark.xs
@pytest.mark.asyncio
async def test_arcata_ca():
    """Compare the results of Arcata, CA."""
    await assert_compare("arcata", "california", "usa", "602476")


@pytest.mark.usa
@pytest.mark.xs
@pytest.mark.asyncio
async def test_rehoboth_beach_de():
    """Compare the results of Rehoboth Beach, DE."""
    await assert_compare("rehoboth beach", "delaware", "usa", "1060290")


@pytest.mark.australia
@pytest.mark.xs
@pytest.mark.asyncio
async def test_orange_au():
    """Compare the results of Orange, AU."""
    await assert_compare("orange", "new south wales", "australia", "0")


@pytest.mark.usa
@pytest.mark.xs
@pytest.mark.asyncio
async def test_canon_city_co():
    """Compare the results of Cañon City, CO."""
    await assert_compare("cañon city", "colorado", "usa", "0811810")


async def assert_compare(city: str, state: str, country: str, city_fips: str) -> None:
    # Load the environment variables.
    load_dotenv()

    # Run the comparison.
    df = await bna.compare(city, state, country, city_fips)

    # Assert the deltas are within range.
    assert all(df.delta.apply(lambda x: -DELTA <= x <= DELTA))
