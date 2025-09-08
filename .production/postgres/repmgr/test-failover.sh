#!/bin/bash
# test-failover.sh

# Simulate primary failure
PRIMARY_CONTAINER=$(docker ps -q -f name=postgres-cluster_postgresql-primary)

if [ -z "$PRIMARY_CONTAINER" ]; then
    echo "Primary container not found!"
    exit 1
fi

echo "Stopping primary container to test failover..."
docker stop $PRIMARY_CONTAINER

echo "Waiting for failover (30 seconds)..."
sleep 30

echo "Checking new cluster status..."
NEW_PRIMARY=$(docker ps -q -f name=postgres-cluster_postgresql -f status=running | head -1)

if [ -z "$NEW_PRIMARY" ]; then
    echo "Failover failed - no running PostgreSQL containers found"
    exit 1
fi

docker exec $NEW_PRIMARY repmgr cluster show
echo "Failover test completed!"