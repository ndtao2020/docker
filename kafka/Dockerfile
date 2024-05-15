FROM eclipse-temurin:21-alpine as builder

# install OpenSSL
RUN apk upgrade --update-cache --available && \
    apk add openssl && \
    rm -rf /var/cache/apk/*

ARG SSL_DOMAIN
ARG SSL_KEYSTORE_FILE
ARG SSL_KEYSTORE_PASSWORD
ARG SSL_TRUSTSTORE_FILE
ARG SSL_TRUSTSTORE_PASSWORD

ENV ALGORITHM=EC
ENV ALIAS=CARoot
ENV VALIDITY_IN_DAYS=3650
ENV COUNTRY=VN
ENV STATE=BinhDinh
ENV OU=ndtao2020
ENV OO=taoqn
ENV CN=${SSL_DOMAIN}
ENV LOCATION=QuyNhon

WORKDIR /app

# https://github.com/confluentinc/learn-kafka-courses/tree/main/fund-kafka-security
# https://docs.confluent.io/platform/current/kafka/encryption.html
# https://docs.confluent.io/platform/current/kafka/authentication_ssl.html#kafka-ssl-authentication
# https://learn.microsoft.com/en-us/azure/hdinsight/kafka/apache-kafka-ssl-encryption-authentication
# list of possible curve names
# RUN openssl ecparam -list_curves
# Create own private Certificate Authority (CA)
RUN openssl ecparam -name secp521r1 -genkey -noout -out private-key.pem
RUN openssl ec -in private-key.pem -pubout -out public-key.pem
RUN openssl req -new -x509 \
    -key private-key.pem \
    -out ca-cert \
    -days $VALIDITY_IN_DAYS \
    -subj "/C=$COUNTRY/ST=$STATE/L=$LOCATION/O=$OU/OU=$OO/CN=$CN" \
    -passin pass:$SSL_KEYSTORE_PASSWORD
# Create Kafka Server Certificate and store in KeyStore
RUN keytool -genkey \
    -keystore $SSL_KEYSTORE_FILE \
    -keyalg $ALGORITHM \
    -validity $VALIDITY_IN_DAYS \
    -dname "C=$COUNTRY, ST=$STATE, L=$LOCATION, O=$OU, OU=$OO, CN=$CN" \
    -storepass $SSL_KEYSTORE_PASSWORD \
    -keypass $SSL_KEYSTORE_PASSWORD \
    -storetype pkcs12
# Create Certificate signed request (CSR)
RUN keytool \
    -keystore $SSL_KEYSTORE_FILE \
    -keyalg $ALGORITHM \
    -certreq -file cert-file \
    -storepass $SSL_KEYSTORE_PASSWORD \
    -keypass $SSL_KEYSTORE_PASSWORD
# Get CSR Signed with the CA
RUN openssl x509 -req \
    -CA ca-cert \
    -CAkey private-key.pem \
    -in cert-file \
    -out cert-file-signed \
    -days $VALIDITY_IN_DAYS \
    -CAcreateserial \
    -passin pass:$SSL_KEYSTORE_PASSWORD
# Import CA certificate in KeyStore
RUN keytool -keystore $SSL_KEYSTORE_FILE -keyalg $ALGORITHM -alias $ALIAS -import -file ca-cert -storepass $SSL_KEYSTORE_PASSWORD -keypass $SSL_KEYSTORE_PASSWORD -noprompt
# Import Signed CSR In KeyStore
RUN keytool -keystore $SSL_KEYSTORE_FILE -keyalg $ALGORITHM -import -file cert-file-signed -storepass $SSL_KEYSTORE_PASSWORD -keypass $SSL_KEYSTORE_PASSWORD -noprompt
# Import CA certificate In TrustStore
RUN keytool -keystore $SSL_TRUSTSTORE_FILE -keyalg $ALGORITHM -alias $ALIAS -import -file ca-cert -storepass $SSL_TRUSTSTORE_PASSWORD -keypass $SSL_KEYSTORE_PASSWORD -noprompt
# import the keystore to another keystore, where you can give a new password for the new PKCS keystore.
# https://confluence.atlassian.com/jirakb/unable-to-access-the-jira-instance-due-to-badpaddingexception-1115154678.html
# RUN keytool -importkeystore \
#     -srckeystore $KAFKA_SSL_KEYSTORE_TEMP_FILE \
#     -srcstoretype PKCS12 \
#     -srcstorepass $KAFKA_SSL_KEY_PASSWORD \
#     -destkeystore $KAFKA_SSL_KEYSTORE_FILE \
#     -deststoretype PKCS12 \
#     -deststorepass $KAFKA_SSL_KEYSTORE_PASSWORD -noprompt

FROM apache/kafka:latest

ARG HOSTNAME
ARG SSL_DOMAIN
ARG SSL_KEYSTORE_FILE
ARG SSL_KEYSTORE_PASSWORD
ARG SSL_TRUSTSTORE_FILE
ARG SSL_TRUSTSTORE_PASSWORD

WORKDIR /app

COPY --from=builder /app/$SSL_KEYSTORE_FILE .
COPY --from=builder /app/$SSL_TRUSTSTORE_FILE .

RUN cp $SSL_KEYSTORE_FILE /etc/kafka/secrets/$HOSTNAME.keystore.jks
RUN cp $SSL_TRUSTSTORE_FILE /etc/kafka/secrets/kafka.truststore.jks

RUN echo ${SSL_KEYSTORE_PASSWORD} > /etc/kafka/secrets/ssl_key_creds
RUN echo ${SSL_KEYSTORE_PASSWORD} > /etc/kafka/secrets/keystore_creds
RUN echo ${SSL_TRUSTSTORE_PASSWORD} > /etc/kafka/secrets/truststore_creds
