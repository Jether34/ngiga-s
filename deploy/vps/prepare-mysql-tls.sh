#!/bin/sh
set -eu

cd "$(dirname "$0")"
docker compose -f compose.yml up -d database

docker compose -f compose.yml exec -T database sh -c '
  set -eu
  cd /var/lib/mysql
  if openssl verify -CAfile ca.pem -verify_hostname database server-cert.pem >/dev/null 2>&1; then
    exit 0
  fi
  if [ ! -f server-cert.pre-ngiga.pem ]; then
    cp server-cert.pem server-cert.pre-ngiga.pem
    cp server-key.pem server-key.pre-ngiga.pem
  fi
  openssl req -new -newkey rsa:3072 -nodes \
    -keyout server-key.ngiga.pem -out server.ngiga.csr \
    -subj /CN=database -addext subjectAltName=DNS:database >/dev/null 2>&1
  printf "subjectAltName=DNS:database\n" > /tmp/ngiga-san.ext
  openssl x509 -req -in server.ngiga.csr -CA ca.pem -CAkey ca-key.pem \
    -CAcreateserial -out server-cert.ngiga.pem -days 3650 -sha256 \
    -extfile /tmp/ngiga-san.ext >/dev/null 2>&1
  openssl verify -CAfile ca.pem -verify_hostname database server-cert.ngiga.pem
  cp server-key.ngiga.pem server-key.pem
  cp server-cert.ngiga.pem server-cert.pem
  chown mysql:mysql server-key.pem server-cert.pem
  chmod 600 server-key.pem
  chmod 644 server-cert.pem
'

docker compose -f compose.yml restart database
docker cp ngiga-stockroom-database-1:/var/lib/mysql/ca.pem /opt/ngiga-stockroom/mysql-ca.pem
chmod 644 /opt/ngiga-stockroom/mysql-ca.pem
