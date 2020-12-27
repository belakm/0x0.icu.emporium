# 0x0.icu.emporium


Installation is done on alpine following the official postgraphile guide: https://www.graphile.org/postgraphile/running-postgraphile-in-docker/

## Create a new Debian 10 container on Digital ocean

## Convert Debian to Alpine linux

1. `wget https://github.com/k4mrul/digitalocean-alpine/raw/master/digitalocean-alpine.sh`
2. `chmod +x digitalocean-alpine.sh`
3. `./digitalocean-alpine.sh --rebuild`

# Add Docker and git

1. Install packages via `apk add docker git`
2. Add to runlevel boot `rc-update add docker boot`
3. Run manually `service docker start`
4. Ensure everything is OK `service docker status`

# Get this project and setup .env variables

1. Clone it `git clone git@github.com:belakm/0x0.icu.emporium.git`
2. Go to its directory `cd 0x0.icu.emporium`
3. Create new env file and fill in your data `cp example.env .env`

# Build images and run containers

1. Build with `docker-compose build`
2. Run with `docker-compose up`