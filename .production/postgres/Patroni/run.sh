#!/bin/sh

# Assume a file named '.env' exists with content like:
export $(grep -v '^#' .env | xargs)

# Create overlay network
docker network create -d overlay patroni-network

# Create secrets (replace with strong values!)
echo -n "$POSTGRES_ADMIN_PASSWORD" | docker secret create pg_superuser_password -
echo -n "$POSTGRES_REPLICATION_PASSWORD" | docker secret create pg_replication_password -
echo -n "$PATRONI_REST_PASSWORD" | docker secret create patroni_rest_password -

# (Optional) App-level user
echo -n "$POSTGRES_PASSWORD" | docker secret create pg_app_password -

# Label three data nodes and two edge nodes for HAProxy
# Define the label key and value you want to add or update
LABEL_KEY="pg"
LABEL_VALUE="1"

# Get a list of all node IDs in the swarm
NODE_IDS=$(docker node ls -q)

# Loop through each node ID and update its label
for NODE_ID in $NODE_IDS; do
    echo "Updating node: $NODE_ID with label $LABEL_KEY=$LABEL_VALUE"
    docker node update --label-add "$LABEL_KEY=$LABEL_VALUE" "$NODE_ID"
    if [ $? -eq 0 ]; then
        echo "Successfully updated node: $NODE_ID"
    else
        echo "Failed to update node: $NODE_ID"
    fi
done

echo "Label update process completed."

# HAProxy config (Swarm Config)
docker config create haproxy_cfg ./haproxy.cfg

# Docker Swarm manager node, deploy the stack with the following command
docker stack deploy -c patroni-stack.yml postgres-ha

# Check the status of your services
docker stack services postgres-ha
