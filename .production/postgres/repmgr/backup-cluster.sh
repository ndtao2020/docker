#!/bin/bash
# backup-cluster.sh

set -e

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backups"
RETENTION_DAYS=7

PRIMARY_CONTAINER=$(docker ps -q -f name=postgres-cluster_postgresql-primary)

if [ -z "$PRIMARY_CONTAINER" ]; then
    echo "Primary container not found!"
    exit 1
fi

# Perform base backup
docker exec $PRIMARY_CONTAINER \
  pg_basebackup -D /backups/base_backup_${DATE} -X stream -U replicator -v -P

# Create compressed archive
tar -czf ${BACKUP_DIR}/postgres_backup_${DATE}.tar.gz -C /backups/base_backup_${DATE} .

# Cleanup
rm -rf /backups/base_backup_${DATE}

# Clean old backups
find ${BACKUP_DIR} -name "*.tar.gz" -mtime +${RETENTION_DAYS} -delete

echo "Backup completed: postgres_backup_${DATE}.tar.gz"