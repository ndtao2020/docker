# Patroni/PostgreSQL on Docker Swarm (Production-Ready Template)

Here is a complete docker-compose.yml file designed for a high-availability PostgreSQL cluster on Docker Swarm, using Patroni for automated failover, etcd as the distributed consensus store, and HAProxy to direct traffic to the primary node.

## Overview of the Components

This setup creates a resilient PostgreSQL environment with three key services working together:

1. etcd 🌳: A simple, reliable key-value store. Patroni uses it to store the cluster's state and manage leader elections. It acts as the "source of truth" for which node is currently the primary.

2. Patroni/PostgreSQL 🐘: This is the core database service. We'll deploy three replicas. Patroni runs in each container, managing the PostgreSQL process. It handles replication, monitors health, and performs automated failover.

3. HAProxy 🚦: A lightweight load balancer. It continuously checks the Patroni API to find out which node is the primary and routes all read/write database connections to it automatically. Your application only needs to connect to HAProxy.

This guide gives you a **ready-to-deploy** Swarm stack for a highly-available PostgreSQL cluster powered by **Patroni** with **etcd** as the DCS and **HAProxy** for a stable write endpoint. It includes production notes, secrets, rolling updates, failover testing, and optional backups/monitoring.

> Target: 3× PostgreSQL (Patroni) + 3× etcd + 2× HAProxy

---

## 1) Prerequisites

- Docker Engine 24+ and Docker Swarm initialized on at least **3 manager-capable nodes**.
- Each node labeled for placement (example below uses `node.labels.pg==1` for data nodes and `node.labels.edge==1` for proxies).
- Reliable shared storage **not required**; we use local volumes per node for maximal performance and isolation. (Backups recommended!)
- You will create Swarm **secrets** for DB users.

---

## 2) Networking & Secrets

```bash
# Create overlay network
docker network create -d overlay patroni-net

# Create secrets (replace with strong values!)
echo -n 'SuperStrongAdminPass' | docker secret create pg_superuser_password -
echo -n 'AnotherStrongRepPass' | docker secret create pg_replication_password -
echo -n 'PatroniRestAPIPass'  | docker secret create patroni_rest_password -

# (Optional) App-level user
# echo -n 'AppUserPass' | docker secret create pg_app_password -
```

> Tip: Use a secrets manager to rotate these.

---

## 3) Node Labeling (example)

```bash
# Label three data nodes and two edge nodes for HAProxy
# Adjust to your actual node hostnames

docker node update --label-add pg=1 swarm-node-1

docker node update --label-add pg=1 swarm-node-2

docker node update --label-add pg=1 swarm-node-3

# Optional: dedicated HAProxy edges
docker node update --label-add edge=1 swarm-edge-1

docker node update --label-add edge=1 swarm-edge-2
```

---

## 4) HAProxy config (Swarm Config)

This config sends writes to the **leader** and provides a **read-only** pool for replicas.

Create `haproxy.cfg` locally:

```cfg
global
  log stdout format raw daemon
  maxconn 4096

defaults
  log     global
  option  dontlognull
  retries 3
  timeout connect 5s
  timeout client  30s
  timeout server  30s

# Patroni REST runs on 8008; PostgreSQL runs on 5432
# --- WRITE (leader) endpoint on 5432 ---
frontend fe_write
  bind *:5432
  default_backend be_write

backend be_write
  mode tcp
  balance roundrobin
  option tcp-check
  # Check Patroni REST to route only to the leader
  # We tunnel an HTTP check over TCP using 'option httpchk'
  option httpchk GET /master HTTP/1.1\r\nHost:\ localhost
  http-check expect status 200
  server patroni1 patroni-1:5432 check inter 2s fall 3 rise 2
  server patroni2 patroni-2:5432 check inter 2s fall 3 rise 2
  server patroni3 patroni-3:5432 check inter 2s fall 3 rise 2

# --- READ-ONLY (replicas) endpoint on 5433 ---
frontend fe_readonly
  bind *:5433
  default_backend be_readonly

backend be_readonly
  mode tcp
  balance roundrobin
  option tcp-check
  option httpchk GET /replica HTTP/1.1\r\nHost:\ localhost
  http-check expect status 200
  server patroni1 patroni-1:5432 check inter 2s fall 3 rise 2
  server patroni2 patroni-2:5432 check inter 2s fall 3 rise 2
  server patroni3 patroni-3:5432 check inter 2s fall 3 rise 2

# Health endpoint for LB status
frontend fe_stats
  bind *:7000
  stats enable
  stats uri /
  stats refresh 5s
```

Create a Swarm **config** from it:

```bash
docker config create haproxy_cfg ./haproxy.cfg
```

---

## 5) Swarm Stack: `patroni-stack.yml`

> Uses **Spilo** (Zalando) image that bundles PostgreSQL + Patroni. Replace image tags with your vetted version. Pin exact tags in production.

```yaml
version: "3.9"

x-pg-env: &pg-env
  # Patroni cluster identity
  SCOPE: "pgprod"
  CLUSTER_NAME: "pgprod"

  # Etcd DCS endpoints (see etcd services below)
  ETCD_HOSTS: "etcd-1:2379,etcd-2:2379,etcd-3:2379"

  # PostgreSQL settings (sane defaults; tune per workload)
  PATRONI_POSTGRESQL_USE_UNIX_SOCKET: "true"
  PATRONI_POSTGRESQL_LISTEN: "0.0.0.0:5432"
  PATRONI_RESTAPI_LISTEN: "0.0.0.0:8008"
  PATRONI_RESTAPI_CONNECT_ADDRESS: "0.0.0.0:8008"

  # Synchronous replication settings (optional; safer writes)
  PATRONI_SYNCHRONOUS_MODE: "true"
  PATRONI_SYNCHRONOUS_MODE_STRICT: "true"
  PATRONI_SYNCHRONOUS_NODE_COUNT: "1"

  # Enable logical replication for downstreams (CDC, read replicas, etc.)
  PATRONI_POSTGRESQL_PARAMETERS: |
    max_connections=400
    shared_buffers=1GB
    wal_level=logical
    max_wal_senders=20
    max_replication_slots=20
    hot_standby=on
    wal_keep_size=512MB
    effective_cache_size=3GB
    maintenance_work_mem=256MB

  # Bootstrap superuser names
  SUPERUSER_USERNAME: "postgres"
  REPLICATION_USERNAME: "replicator"

  # Patroni REST auth (protects write operations like switchover)
  PATRONI_RESTAPI_USERNAME: "patroni"

  # Optional init DBs / users via SPILO_CONFIGURATION
  SPILO_CONFIGURATION: |
    bootstrap:
      dcs:
        postgresql:
          parameters:
            shared_buffers: 1GB
      initdb:
        - auth-host: scram-sha-256
        - auth-local: scram-sha-256
        - encoding: UTF8
        - data-checksums
    postgresql:
      use_unix_socket: true

secrets:
  pg_superuser_password:
    external: true
  pg_replication_password:
    external: true
  patroni_rest_password:
    external: true

configs:
  haproxy_cfg:
    external: true

networks:
  patroni-net:
    external: true

volumes:
  pgdata-1:
  pgdata-2:
  pgdata-3:

services:
  # -----------------------
  # Etcd quorum (3 nodes)
  # -----------------------
  etcd-1:
    image: bitnami/etcd:3.5
    command: >-
      /opt/bitnami/etcd/bin/etcd \
      --name etcd-1 \
      --data-dir /bitnami/etcd \
      --initial-advertise-peer-urls http://etcd-1:2380 \
      --listen-peer-urls http://0.0.0.0:2380 \
      --listen-client-urls http://0.0.0.0:2379 \
      --advertise-client-urls http://etcd-1:2379 \
      --initial-cluster-token etcd-cluster-1 \
      --initial-cluster etcd-1=http://etcd-1:2380,etcd-2=http://etcd-2:2380,etcd-3=http://etcd-3:2380 \
      --initial-cluster-state new
    networks: [patroni-net]
    deploy:
      placement:
        constraints: ["node.labels.pg == 1"]

  etcd-2:
    image: bitnami/etcd:3.5
    command: >-
      /opt/bitnami/etcd/bin/etcd \
      --name etcd-2 \
      --data-dir /bitnami/etcd \
      --initial-advertise-peer-urls http://etcd-2:2380 \
      --listen-peer-urls http://0.0.0.0:2380 \
      --listen-client-urls http://0.0.0.0:2379 \
      --advertise-client-urls http://etcd-2:2379 \
      --initial-cluster-token etcd-cluster-1 \
      --initial-cluster etcd-1=http://etcd-1:2380,etcd-2=http://etcd-2:2380,etcd-3=http://etcd-3:2380 \
      --initial-cluster-state new
    networks: [patroni-net]
    deploy:
      placement:
        constraints: ["node.labels.pg == 1"]

  etcd-3:
    image: bitnami/etcd:3.5
    command: >-
      /opt/bitnami/etcd/bin/etcd \
      --name etcd-3 \
      --data-dir /bitnami/etcd \
      --initial-advertise-peer-urls http://etcd-3:2380 \
      --listen-peer-urls http://0.0.0.0:2380 \
      --listen-client-urls http://0.0.0.0:2379 \
      --advertise-client-urls http://etcd-3:2379 \
      --initial-cluster-token etcd-cluster-1 \
      --initial-cluster etcd-1=http://etcd-1:2380,etcd-2=http://etcd-2:2380,etcd-3=http://etcd-3:2380 \
      --initial-cluster-state new
    networks: [patroni-net]
    deploy:
      placement:
        constraints: ["node.labels.pg == 1"]

  # -------------------------------------
  # Patroni + PostgreSQL (Spilo) x 3
  # -------------------------------------
  patroni-1:
    image: ghcr.io/zalando/spilo-15:latest
    environment:
      <<: *pg-env
    secrets:
      - source: pg_superuser_password
        target: /run/secrets/pg_superuser_password
      - source: pg_replication_password
        target: /run/secrets/pg_replication_password
      - source: patroni_rest_password
        target: /run/secrets/patroni_rest_password
    volumes:
      - pgdata-1:/home/postgres/pgdata
    networks: [patroni-net]
    ports:
      - target: 8008
        published: 8001
        mode: host
    deploy:
      replicas: 1
      placement:
        constraints:
          - "node.labels.pg == 1"
      restart_policy:
        condition: on-failure

  patroni-2:
    image: ghcr.io/zalando/spilo-15:latest
    environment:
      <<: *pg-env
    secrets:
      - source: pg_superuser_password
        target: /run/secrets/pg_superuser_password
      - source: pg_replication_password
        target: /run/secrets/pg_replication_password
      - source: patroni_rest_password
        target: /run/secrets/patroni_rest_password
    volumes:
      - pgdata-2:/home/postgres/pgdata
    networks: [patroni-net]
    ports:
      - target: 8008
        published: 8002
        mode: host
    deploy:
      replicas: 1
      placement:
        constraints:
          - "node.labels.pg == 1"
      restart_policy:
        condition: on-failure

  patroni-3:
    image: ghcr.io/zalando/spilo-15:latest
    environment:
      <<: *pg-env
    secrets:
      - source: pg_superuser_password
        target: /run/secrets/pg_superuser_password
      - source: pg_replication_password
        target: /run/secrets/pg_replication_password
      - source: patroni_rest_password
        target: /run/secrets/patroni_rest_password
    volumes:
      - pgdata-3:/home/postgres/pgdata
    networks: [patroni-net]
    ports:
      - target: 8008
        published: 8003
        mode: host
    deploy:
      replicas: 1
      placement:
        constraints:
          - "node.labels.pg == 1"
      restart_policy:
        condition: on-failure

  # -----------------------
  # HAProxy (2 replicas)
  # -----------------------
  haproxy:
    image: haproxy:2.9
    networks: [patroni-net]
    ports:
      - target: 5432
        published: 5432
        protocol: tcp
        mode: host
      - target: 5433
        published: 5433
        protocol: tcp
        mode: host
      - target: 7000
        published: 7000
        protocol: tcp
        mode: host
    configs:
      - source: haproxy_cfg
        target: /usr/local/etc/haproxy/haproxy.cfg
    deploy:
      replicas: 2
      placement:
        constraints: ["node.labels.edge == 1"]
      restart_policy:
        condition: on-failure
```

**Important:** The Spilo image consumes secrets via environment variables. Map secrets into env at runtime by reading files in an entrypoint wrapper or set env like below (add to each Patroni service if you prefer env approach):

```yaml
environment:
  PGPASSWORD_SUPERUSER_FILE: "/run/secrets/pg_superuser_password"
  PGPASSWORD_REPLICATION_FILE: "/run/secrets/pg_replication_password"
  PATRONI_RESTAPI_PASSWORD_FILE: "/run/secrets/patroni_rest_password"
```

If your Spilo build expects different variable names (e.g., `SUPERUSER_PASSWORD`, `REPLICATION_PASSWORD`), adjust accordingly. Pin a **specific** Spilo tag you trust.

---

## 6) Deploy

```bash
# Validate YAML
docker stack deploy -c patroni-stack.yml pgstack

# Check services
watch -n 2 'docker stack services pgstack'

# Logs (example)
docker service logs -f pgstack_patroni-1
```

Initial bootstrap: Patroni will initialize a leader. etcd must be healthy first.

---

## 7) How to Connect

- **Write (leader):** `postgres://postgres:<password>@<any-haproxy-node>:5432/postgres`
- **Read-only (replicas):** `postgres://postgres:<password>@<any-haproxy-node>:5433/postgres`
- **HAProxy stats:** `http://<any-haproxy-node>:7000/`
- **Patroni REST:** `http://<patroni-node>:8001|8002|8003/` (per-node, published via host mode in example)

> Replace `<password>` with the `pg_superuser_password` secret value.

---

## 8) Failover & Switchover

- **Automatic failover:** If the leader dies, Patroni promotes a healthy replica.
- **Manual switchover:**

```bash
# Example: ask Patroni REST to switchover leader to patroni-2
curl -u patroni:$(cat /run/secrets/patroni_rest_password) \
  -X POST http://<leader-host>:8008/switchover \
  -H 'Content-Type: application/json' \
  -d '{"candidate":"patroni-2","scheduled_at":null}'
```

- **Test failover:** Stop a Patroni task and check HAProxy (`:7000`) and `SELECT pg_is_in_recovery()` via `5432`/`5433`.

---

## 9) Rolling Updates

```bash
# Pin the new Spilo tag in patroni-stack.yml, then:
docker stack deploy -c patroni-stack.yml pgstack

# Patroni + Swarm will replace tasks one-by-one; leader step-down may occur.
# Verify replicas are healthy before each replacement.
```

---

## 10) Backups (WAL-G) — Optional

For S3-compatible backups:

- Add env to each Patroni service (and mount credentials securely):

```yaml
environment:
  WAL_S3_BUCKET: "s3://my-pg-backups"
  AWS_ACCESS_KEY_ID_FILE: "/run/secrets/aws_access_key_id"
  AWS_SECRET_ACCESS_KEY_FILE: "/run/secrets/aws_secret_access_key"
  AWS_ENDPOINT: "https://s3.mycompany.local"  # if MinIO/ceph
  USE_WALG_BACKUP: "true"
```

- Create secrets for keys and schedule `wal-g backup-push` via a sidecar or cron container.

- Restore is done by setting `USE_WALG_RESTORE=true` and pointing to a base backup.

---

## 11) Monitoring — Optional

- **pg_exporter** or **postgres_exporter** (Prometheus) on each patroni node.
- Alert on:
  - `pg_is_in_recovery` (leader vs replicas)
  - replication lag (bytes/seconds)
  - `etcd` quorum health
  - HAProxy backend up/down

---

## 12) Security & Hardening Checklist

- Pin **exact image tags** for Spilo, etcd, HAProxy.
- Use **SCRAM-SHA-256** auth (enabled in `initdb`), and rotate passwords via Swarm secrets.
- Restrict network access (firewall) to `5432/5433/7000/800x` as needed.
- Consider **synchronous replication** only if you accept write latency during replica outages (we set it on by default here).
- Ensure node time sync (NTP/Chrony) — split-brain prevention.
- Backups tested regularly (WAL-G or your solution).

---

## 13) Logical Replication Notes

- `wal_level=logical` is enabled. Create publication/subscription as usual:

```sql
-- on leader
CREATE PUBLICATION app_pub FOR TABLE my_schema.my_table;

-- on downstream subscriber
CREATE SUBSCRIPTION app_sub
  CONNECTION 'host=<haproxy> port=5433 dbname=app user=replicator password=...'
  PUBLICATION app_pub;
```

Use the **read-only** endpoint (`5433`) for subscribers if you want them to follow a replica; otherwise point to `5432` for the leader only.

---

## 14) Troubleshooting

- Patroni logs per node: `docker service logs -f pgstack_patroni-1` (or `-2`, `-3`).
- etcd health: `docker exec -it <etcd-task> etcdctl endpoint health --cluster`.
- Check DCS: `curl http://<patroni-node>:8008/health` and `.../cluster`.
- If cluster won’t bootstrap, ensure etcd is healthy and DNS names (`patroni-1`, `-2`, `-3`) resolve on the overlay network.

---

## 15) Variations

- **Use Consul** instead of etcd: set `DCS=consul` and `CONSUL_URL` in env.
- **No synchronous replication**: set `PATRONI_SYNCHRONOUS_MODE=false`.
- **Dedicated storage class**: swap local volumes for a CSI driver or NFS if you accept the trade-offs.

---

### Ready to adapt?
Tell me your node hostnames, image tags you prefer, and any PostgreSQL tuning targets (RAM/CPU/IOPS). I’ll tailor this to your exact production setup.

