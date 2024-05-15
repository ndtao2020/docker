#!/bin/sh

set -eu

ALGORITHM=$1
ALIAS=CARoot
VALIDITY_IN_DAYS=3650
COUNTRY=VN
STATE=BinhDinh
OU=ndtao2020
OO=taoqn
CN=$2
LOCATION=QuyNhon
KAFKA_SSL_PASSWORD=${KAFKA_SSL_PASSWORD}
KAFKA_SSL_KEYSTORE_FILE=kafka.server.keystore.jks
KAFKA_SSL_TRUSTSTORE_FILE=kafka.server.truststore.jks

function file_exists_and_exit() {
  echo "'$1' cannot exist. Move or delete it before"
  echo "re-running this script."
  exit 1
}

if [ -e "$KEYSTORE_WORKING_DIRECTORY" ]; then
  file_exists_and_exit $KEYSTORE_WORKING_DIRECTORY
fi

if [ -e "$CA_CERT_FILE" ]; then
  file_exists_and_exit $CA_CERT_FILE
fi

if [ -e "$KEYSTORE_SIGN_REQUEST" ]; then
  file_exists_and_exit $KEYSTORE_SIGN_REQUEST
fi

if [ -e "$KEYSTORE_SIGN_REQUEST_SRL" ]; then
  file_exists_and_exit $KEYSTORE_SIGN_REQUEST_SRL
fi

if [ -e "$KEYSTORE_SIGNED_CERT" ]; then
  file_exists_and_exit $KEYSTORE_SIGNED_CERT
fi
