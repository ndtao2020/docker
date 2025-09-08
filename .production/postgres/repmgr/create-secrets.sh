#!/bin/bash
# create-secrets.sh

set -e

# Generate strong passwords
POSTGRESQL_POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d '/+=' | cut -c1-24)
POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d '/+=' | cut -c1-24)
REPLICATION_PASSWORD=$(openssl rand -base64 32 | tr -d '/+=' | cut -c1-24)
REPMGR_PASSWORD=$(openssl rand -base64 32 | tr -d '/+=' | cut -c1-24)

# Create Docker secrets
echo "$POSTGRESQL_POSTGRES_PASSWORD" | docker secret create postgres_root_password -
echo "$POSTGRES_PASSWORD" | docker secret create postgres_password -
echo "$REPLICATION_PASSWORD" | docker secret create replication_password -
echo "$REPMGR_PASSWORD" | docker secret create repmgr_password -

# Export for docker-compose
# export POSTGRESQL_POSTGRES_PASSWORD=$(docker secret inspect postgres_root_password --format '{{.Spec.Name}}')
# export POSTGRES_PASSWORD=$(docker secret inspect postgres_password --format '{{.Spec.Name}}')
# export REPLICATION_PASSWORD=$(docker secret inspect replication_password --format '{{.Spec.Name}}')
# export REPMGR_PASSWORD=$(docker secret inspect repmgr_password --format '{{.Spec.Name}}')

# Save passwords to secure location (optional)
echo "POSTGRESQL_POSTGRES_PASSWORD=$POSTGRESQL_POSTGRES_PASSWORD" > .env
echo "POSTGRES_PASSWORD=$POSTGRES_PASSWORD" >> .env
echo "REPLICATION_PASSWORD=$REPLICATION_PASSWORD" >> .env
echo "REPMGR_PASSWORD=$REPMGR_PASSWORD" >> .env

chmod 600 .env

echo "Secrets created successfully!"
