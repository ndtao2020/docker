#!/bin/bash
# deploy-postgres-cluster.sh

set -e

# Create networks
docker network create -d overlay postgres_internal --internal --attachable || true
docker network create -d overlay app_network --attachable || true

# Deploy the stack
docker stack deploy -c docker-compose.yml postgres-cluster

echo "PostgreSQL cluster deployment started!"
echo "Monitor with: docker service ls"
echo "Check logs with: docker service logs postgres-cluster_postgresql-primary"
