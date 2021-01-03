# 0x0.icu.emporium

Database and api services for 0x0.icu stack

# Access

Each container can be accessed at the following addresses:

GraphQL API Documentation	`:5433/graphiql`
GraphQL API	`:5433/graphql`
PostgreSQL Database	host: `localhost`, port: `5432`

# Installation

## 1. Create a new Debian 10 container on Digital ocean

## 2. Convert Debian to Alpine linux

1. `wget https://github.com/k4mrul/digitalocean-alpine/raw/master/digitalocean-alpine.sh`
2. `chmod +x digitalocean-alpine.sh`
3. `./digitalocean-alpine.sh --rebuild`

## 3. Add docker, docker-compose and git

1. Install packages via `apk add docker docker-compose git`
2. Add to runlevel boot `rc-update add docker boot`
3. Run manually `service docker start`
4. Ensure everything is OK `service docker status`

## 4. Get this project and setup .env variables

1. Clone it `git clone https://github.com/belakm/0x0.icu.emporium.git`
2. Go to its directory `cd 0x0.icu.emporium`
3. Create new env file by copying example `cp example.env .env`
4. Fill in the env secrets `vi .env`

## 5. Build images and run containers

1. Build with `docker-compose build`
2. Run with `docker-compose up`