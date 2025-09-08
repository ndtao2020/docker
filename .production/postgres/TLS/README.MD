# Step 1: Generate TLS Certificates

First, we need to create a Certificate Authority (CA) and then use it to sign certificates for our services. You can do this on your local machine or the Swarm manager node.

Create a directory to work in:

```bash
mkdir pg-ha-tls && cd pg-ha-tls
```

Now, run these openssl commands to generate the necessary files:

```bash
# 1. Generate a private key for your Certificate Authority (CA)
openssl genrsa -out ca.key 4096

# 2. Create the CA root certificate
openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 \
  -subj "/CN=pg.ha.ca" -out ca.crt

# 3. Generate a private key for the server (for Patroni & etcd)
openssl genrsa -out server.key 2048

# 4. Create a certificate signing request (CSR) for the server.
# We need to list all DNS names and IPs the certificate will be used for.
# This includes service names from docker-compose.yml.
openssl req -new -key server.key \
  -subj "/CN=patroni" \
  -addext "subjectAltName = DNS:etcd, DNS:patroni, DNS:localhost, IP:127.0.0.1" \
  -out server.csr

# 5. Sign the server certificate with your CA
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out server.crt -days 730 -sha256 \
  -extfile <(printf "subjectAltName = DNS:etcd, DNS:patroni, DNS:localhost, IP:127.0.0.1")

# 6. Generate a private key for the client (for Patroni to talk to etcd)
openssl genrsa -out client.key 2048

# 7. Create a CSR for the client
openssl req -new -key client.key -subj "/CN=patroni-client" -out client.csr

# 8. Sign the client certificate with your CA
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out client.crt -days 730 -sha256
```

You should now have several .key and .crt files in your directory.

# Step 2: Create Docker Secrets from Certificates

Next, create Docker secrets from the generated files. This is the secure way to make them available to the services inside the containers.

```bash
# CA Certificate
docker secret create ca.crt ca.crt

# Server Certificate and Key
docker secret create server.crt server.crt
docker secret create server.key server.key

# Client Certificate and Key
docker secret create client.crt client.crt
docker secret create client.key client.key
```

And don't forget the password secrets from the previous guide:

```bash
echo "your_super_password" | docker secret create patroni_superuser_password -
echo "your_repl_password" | docker secret create patroni_replication_password -
```

# Step 3: Updated docker-compose.yml with TLS

Here is the modified docker-compose.yml. Key changes are commented to explain what they do. It now includes references to the TLS secrets and the environment variables needed to enable encryption.

```bash
version: '3.8'

services:
  # -----------------------------------------------------------------
  # etcd: Now secured with TLS
  # -----------------------------------------------------------------
  etcd:
    image: bitnami/etcd:3.5
    networks:
      - postgres-ha-net
    secrets: # Mount TLS secrets
      - ca.crt
      - server.crt
      - server.key
    environment:
      # --- Disable non-TLS communication ---
      - ALLOW_NONE_AUTHENTICATION=no
      # --- Enable TLS for client connections ---
      - ETCD_CLIENT_CERT_AUTH=true
      - ETCD_CERT_FILE=/run/secrets/server.crt
      - ETCD_KEY_FILE=/run/secrets/server.key
      - ETCD_TRUSTED_CA_FILE=/run/secrets/ca.crt
      - ETCD_ADVERTISE_CLIENT_URLS=https://etcd:2379
      - ETCD_LISTEN_CLIENT_URLS=https://0.0.0.0:2379
    deploy:
      replicas: 1
      placement:
        constraints: [node.role == manager]

  # -----------------------------------------------------------------
  # Patroni/PostgreSQL: Now secured with TLS
  # -----------------------------------------------------------------
  patroni:
    image: bitnami/patroni:2.1
    networks:
      - postgres-ha-net
    secrets:
      # Password secrets
      - patroni_superuser_password
      - patroni_replication_password
      # TLS secrets
      - ca.crt
      - server.crt
      - server.key
      - client.crt
      - client.key
    environment:
      # --- Patroni Configuration ---
      - PATRONI_SCOPE=pgcluster
      - PATRONI_NAME=${HOSTNAME}
      - PATRONI_RESTAPI_CONNECT_ADDRESS=${HOSTNAME}:8008
      - PATRONI_RESTAPI_LISTEN=0.0.0.0:8008

      # --- etcd connection settings (now with TLS) ---
      - PATRONI_ETCD_PROTOCOL=https
      - PATRONI_ETCD_HOSTS=etcd:2379
      - PATRONI_ETCD_CACERT=/run/secrets/ca.crt
      - PATRONI_ETCD_CERT=/run/secrets/client.crt
      - PATRONI_ETCD_KEY=/run/secrets/client.key

      # --- Patroni REST API TLS settings ---
      - PATRONI_RESTAPI_CERTFILE=/run/secrets/server.crt
      - PATRONI_RESTAPI_KEYFILE=/run/secrets/server.key
      - PATRONI_RESTAPI_CAFILE=/run/secrets/ca.crt

      # --- PostgreSQL Configuration (now with SSL) ---
      - POSTGRESQL_CONNECT_ADDRESS=${HOSTNAME}:5432
      - POSTGRESQL_LISTEN=0.0.0.0:5432
      - POSTGRESQL_DATA_DIR=/var/lib/postgresql/data/pgdata
      - PATRONI_POSTGRESQL_PARAMETERS_ssl=on
      - PATRONI_POSTGRESQL_PARAMETERS_ssl_ca_file=/run/secrets/ca.crt
      - PATRONI_POSTGRESQL_PARAMETERS_ssl_cert_file=/run/secrets/server.crt
      - PATRONI_POSTGRESQL_PARAMETERS_ssl_key_file=/run/secrets/server.key
      
      # --- Replication & Superuser credentials ---
      - PATRONI_REPLICATION_USERNAME=replicator
      - PATRONI_REPLICATION_PASSWORD_FILE=/run/secrets/patroni_replication_password
      - PATRONI_SUPERUSER_USERNAME=postgres
      - PATRONI_SUPERUSER_PASSWORD_FILE=/run/secrets/patroni_superuser_password
    deploy:
      replicas: 3
      restart_policy:
        condition: on-failure
    volumes:
      - patroni_data:/var/lib/postgresql/data

  # -----------------------------------------------------------------
  # HAProxy: Updated for TLS health checks
  # -----------------------------------------------------------------
  haproxy:
    image: haproxy:2.5
    networks:
      - postgres-ha-net
    ports:
      - "5432:5432"  # PostgreSQL with TLS (SSL)
      - "8404:8404"  # HAProxy stats page
    secrets: # Mount CA cert to verify Patroni's API
      - ca.crt
    configs:
      - source: haproxy_config
        target: /usr/local/etc/haproxy/haproxy.cfg
    deploy:
      replicas: 1
      placement:
        constraints: [node.role == manager]

# -------------------------------------------------------------------
# Define external resources (networks and secrets)
# -------------------------------------------------------------------
networks:
  postgres-ha-net:
    external: true

secrets:
  patroni_superuser_password: { external: true }
  patroni_replication_password: { external: true }
  ca.crt: { external: true }
  server.crt: { external: true }
  server.key: { external: true }
  client.crt: { external: true }
  client.key: { external: true }

# -------------------------------------------------------------------
# HAProxy Configuration: Updated to use HTTPS for health checks
# -------------------------------------------------------------------
configs:
  haproxy_config:
    content: |
      global
          maxconn 256
          stats socket /var/run/api.sock user haproxy group haproxy mode 660 level admin
          log stdout format raw local0
          # Define where HAProxy can find CA certificates to verify peers
          ca-base /etc/ssl/certs
          crt-base /etc/ssl/private

      defaults
          log global
          mode tcp
          timeout connect 5s
          timeout client 1m
          timeout server 1m

      frontend postgresql_frontend
          bind *:5432
          default_backend postgresql_backend

      backend postgresql_backend
          option httpchk
          # Use Patroni's HTTPS REST API endpoint for health checks
          http-check send meth GET uri /primary
          # Add 'ssl' to enable TLS and 'verify required' to validate the cert
          # 'ca-file' points to the mounted CA secret
          server-template patroni- 3 tasks.patroni:8008 check port 8008 ssl verify required ca-file /run/secrets/ca.crt

      listen stats
          bind *:8404
          mode http
          stats enable
          stats uri /
          stats refresh 5s
          stats admin if TRUE

volumes:
  patroni_data:
    driver: local
```

# Step 4: Deploy the Secure Stack

Now you can deploy your stack using the same command as before. Docker Swarm will read the updated file and apply the changes.

```sh
# If you are redeploying, run this command from the directory with your docker-compose.yml
docker stack deploy -c docker-compose.yml postgres-ha
```

Your HA PostgreSQL cluster is now running with TLS encryption on all critical communication paths. To connect, your client application will need to use a connection string that enables SSL, for example: 

`postgresql://postgres:your_super_password@<swarm_manager_ip>:5432/postgres?sslmode=require.`
