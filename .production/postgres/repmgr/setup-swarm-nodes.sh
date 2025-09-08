#!/bin/bash
# setup-swarm-nodes.sh

# # Initialize swarm on manager node
# if ! docker node ls &> /dev/null; then
#     docker swarm init --advertise-addr <MANAGER_IP>
# fi

# Add node labels for placement constraints
NODES=$(docker node ls -q)
PRIMARY_NODE=$(docker node ls -q | head -1)

# Label nodes
docker node update --label-add postgresql.role=primary $PRIMARY_NODE
# docker node update --label-add az=zone-a $PRIMARY_NODE

# Label other nodes as replicas
REPLICA_NODES=$(docker node ls -q | tail -n +2)
COUNTER=1
for NODE in $REPLICA_NODES; do
    docker node update --label-add postgresql.role=replica $NODE
    # docker node update --label-add az=zone-$((COUNTER % 2 + 1)) $NODE
    COUNTER=$((COUNTER + 1))
done

echo "Swarm nodes labeled successfully!"
