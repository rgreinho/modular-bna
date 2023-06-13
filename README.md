# modular-bna

Source the .env file:

```bash
export $(cat .env | xargs)
```

Start and stop a clean docker-compose:

```bash
docker-compose up && docker-compose rm -f
```

Download part of the files to import for Flagstaff, AZ:

```bash
just setup-flagstaff
```

The rest of the files must come from the brokenspoke-analyzer:

```bash
bna -v run arizona flagstaff
```

And copy the `data/flagstaff-arizona*` files into the test folder
`test/usa-az-flagstaff`.
