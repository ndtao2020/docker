#!/bin/bash
# deploy-postgres-cluster.sh

set -e

# Create networks
# docker network create -d overlay postgres_internal --internal --attachable || true

# Deploy the stack
# env $(cat .env | xargs) docker stack deploy -c docker-compose.yml pg-repmgr-cluster
# env $(grep -v '^#' .env | xargs) docker stack deploy -c docker-compose.yml pg-repmgr-cluster
env $(grep -v '^#' .env | xargs) docker stack deploy --compose-file docker-compose.yml pg-repmgr-cluster

echo "PostgreSQL cluster deployment started!"

docker service ls
