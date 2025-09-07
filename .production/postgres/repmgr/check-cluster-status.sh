#!/bin/bash
# check-cluster-status.sh

PRIMARY_CONTAINER=$(docker ps -q -f name=postgres-cluster_postgresql-primary)

if [ -z "$PRIMARY_CONTAINER" ]; then
    echo "Primary container not found!"
    exit 1
fi

# Check repmgr cluster status
docker exec $PRIMARY_CONTAINER repmgr cluster show

# Check replication status
docker exec $PRIMARY_CONTAINER psql -U postgres -c "
SELECT client_addr, state, sync_state, write_lag, flush_lag, replay_lag 
FROM pg_stat_replication;"