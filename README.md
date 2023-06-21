# modular-bna

Source the .env file:

```bash
export $(cat .env | xargs)
```

Start and stop a clean docker-compose:

```bash
docker-compose up
docker-compose rm -f
```

Use the brokenspoke-analyzer to fetch the data to import into the BNA:

```bash
bna -v prepare massachusetts provincetown --output-dir tests/samples/provincetown-massachusetts/data
```

Source the analysis variables:

```bash
export $(cat tests/scripts/provincetown-massachusetts.sh | xargs)
```

Run the analysis script (optionally in debug mode):

```bash
bash -x tests/scripts/run-analysis.sh
```

To clean up the variables before running a new analysis (optional, just to be safe):

```bash
unset BNA_CITY BNA_CITY BNA_FULL_STATE BNA_CITY_FIPS BNA_COUNTRY BNA_SHORT_STATE BNA_STATE_FIPS
```

Run the analysis with the original bna:

```bash
bna analyze massachusetts \
  tests/samples/provincetown-massachusetts/data/provincetown-massachusetts.shp \
  tests/samples/provincetown-massachusetts/data/provincetown-massachusetts.osm \
  --output-dir tests/samples/provincetown-massachusetts/outputs
```
