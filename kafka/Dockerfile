FROM openjdk:17-alpine as builder

# install OpenSSL
RUN apk upgrade --update-cache --available && \
    apk add openssl && \
    rm -rf /var/cache/apk/*

ARG KAFKA_SSL_HOSTNAME
ARG KAFKA_SSL_PASSWORD

ENV VALIDITY_IN_DAYS=3650
ENV COUNTRY=VN
ENV STATE=BinhDinh
ENV OU=ndtao2020
ENV CN=${KAFKA_SSL_HOSTNAME}
ENV LOCATION=QuyNhon
ENV KAFKA_SSL_PASSWORD=${KAFKA_SSL_PASSWORD}
ENV KAFKA_SSL_KEYSTORE_FILE=kafka.server.keystore.jks
ENV KAFKA_SSL_TRUSTSTORE_FILE=kafka.server.truststore.jks

WORKDIR /app

# Create own private Certificate Authority (CA)
# https://github.com/confluentinc/learn-kafka-courses/tree/main/fund-kafka-security
# https://docs.confluent.io/platform/current/kafka/encryption.html
# https://docs.confluent.io/platform/current/kafka/authentication_ssl.html#kafka-ssl-authentication
# https://learn.microsoft.com/en-us/azure/hdinsight/kafka/apache-kafka-ssl-encryption-authentication
RUN openssl req -new -nodes \
   -x509 \
   -days $VALIDITY_IN_DAYS \
   -newkey rsa:2048 \
   -keyout ca-key \
   -out ca-cert \
   -subj "/C=$COUNTRY/ST=$STATE/L=$LOCATION/O=$OU/CN=$CN" -passin pass:$KAFKA_SSL_PASSWORD
# Create Kafka Server Certificate and store in KeyStore
RUN keytool -genkey \
    -keystore $KAFKA_SSL_KEYSTORE_FILE \
    -keyalg RSA \
    -validity $VALIDITY_IN_DAYS \
    -dname "C=$COUNTRY, ST=$STATE, L=$LOCATION, O=$OU, CN=$CN" \
    -storepass $KAFKA_SSL_PASSWORD \
    -keypass $KAFKA_SSL_PASSWORD \
    -storetype pkcs12
# Create Certificate signed request (CSR)
RUN keytool -keystore $KAFKA_SSL_KEYSTORE_FILE -keyalg RSA -certreq -file cert-file -storepass $KAFKA_SSL_PASSWORD -keypass $KAFKA_SSL_PASSWORD
# Get CSR Signed with the CA
RUN openssl x509 -req -CA ca-cert -CAkey ca-key -in cert-file -out cert-file-signed -days $VALIDITY_IN_DAYS -CAcreateserial -passin pass:$KAFKA_SSL_PASSWORD
# Import CA certificate in KeyStore
RUN keytool -keystore $KAFKA_SSL_KEYSTORE_FILE -alias CARoot -import -file ca-cert -storepass $KAFKA_SSL_PASSWORD -keypass $KAFKA_SSL_PASSWORD -noprompt
# Import Signed CSR In KeyStore
RUN keytool -keystore $KAFKA_SSL_KEYSTORE_FILE -import -file cert-file-signed -storepass $KAFKA_SSL_PASSWORD -keypass $KAFKA_SSL_PASSWORD -noprompt
# Import CA certificate In TrustStore
RUN keytool -keystore $KAFKA_SSL_TRUSTSTORE_FILE -alias CARoot -import -file ca-cert -storepass $KAFKA_SSL_PASSWORD -keypass $KAFKA_SSL_PASSWORD -noprompt

FROM apache/kafka:latest

ARG KAFKA_SSL_PASSWORD

ENV KAFKA_SSL_PASSWORD=${KAFKA_SSL_PASSWORD}
ENV KAFKA_SSL_KEYSTORE_FILE=kafka.server.keystore.jks
ENV KAFKA_SSL_TRUSTSTORE_FILE=kafka.server.truststore.jks

WORKDIR /app

COPY --from=builder /app/$KAFKA_SSL_KEYSTORE_FILE .
COPY --from=builder /app/$KAFKA_SSL_TRUSTSTORE_FILE .

RUN cp $KAFKA_SSL_KEYSTORE_FILE /etc/kafka/secrets/kafka01.keystore.jks
RUN cp $KAFKA_SSL_TRUSTSTORE_FILE /etc/kafka/secrets/kafka.truststore.jks

RUN echo $KAFKA_SSL_PASSWORD > /etc/kafka/secrets/kafka_keystore_creds
RUN echo $KAFKA_SSL_PASSWORD > /etc/kafka/secrets/kafka_ssl_key_creds
RUN echo $KAFKA_SSL_PASSWORD > /etc/kafka/secrets/kafka_truststore_creds
