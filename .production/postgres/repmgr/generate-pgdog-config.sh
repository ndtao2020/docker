#!/bin/bash

# Export variables from the file, ignoring comments and empty lines
export $(grep -v '^#' .env | xargs)

# Set default value if POSTGRES_DB is not set
POSTGRES_PORT=${POSTGRES_PORT:-5432}
POSTGRES_DB=${POSTGRES_DB:-"postgres"}

# Generate pgdog.toml file with environment variable substitution
cat > ./pgdog/pgdog.toml << EOF
[general]
default_pool_size = 10
min_pool_size = 0
pooler_mode = "transaction"
workers = 0

auth_type = "md5"
passthrough_auth = "enabled_plain"

[admin]
name = "admin"
user = "admin"
password = "admin"

[[databases]]
name = "pg-1"
host = "pg-1"
port = ${POSTGRES_PORT}
user = "${POSTGRES_USER}"
password = "${POSTGRES_PASSWORD}"
database_name = "${POSTGRES_DB}"
role = "primary"

[[databases]]
name = "pg-2"
host = "pg-2"
port = ${POSTGRES_PORT}
user = "${POSTGRES_USER}"
password = "${POSTGRES_PASSWORD}"
database_name = "${POSTGRES_DB}"
role = "replica"
read_only = true

[[databases]]
name = "pg-3"
host = "pg-3"
port = ${POSTGRES_PORT}
user = "${POSTGRES_USER}"
password = "${POSTGRES_PASSWORD}"
database_name = "${POSTGRES_DB}"
role = "replica"
read_only = true
EOF

echo "pgdog.toml has been generated successfully!"

# # Generate pgdog.toml file with environment variable substitution
# cat > ./pgdog/users.toml << EOF
# [[users]]
# database = "pg-1"
# name = "${POSTGRES_USER}"
# password = "${POSTGRES_PASSWORD}"

# [[users]]
# database = "pg-2"
# name = "${POSTGRES_USER}"
# password = "${POSTGRES_PASSWORD}"

# [[users]]
# database = "pg-3"
# name = "${POSTGRES_USER}"
# password = "${POSTGRES_PASSWORD}"
# EOF

# echo "users.toml has been generated successfully!"
