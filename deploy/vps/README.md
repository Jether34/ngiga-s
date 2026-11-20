# Stockroom VPS deployment

The API and MySQL database run in the `ngiga-stockroom` Docker Compose project. The API listens only on `127.0.0.1:8765` on the VPS. Nginx forwards `https://pns-sysnnova.cloud/stockroom-api/` to that loopback port; other applications retain their own routes and containers.

The deployment uses a private `.env` file beside `compose.yml`. Supply `MYSQL_ROOT_PASSWORD`, `MYSQL_PASSWORD`, `SECRET_KEY`, `ADMIN_EMAIL`, and `ADMIN_PASSWORD`. Keep this file out of Git.

Deploy from the repository root on the VPS:

```sh
cd /opt/ngiga-stockroom/deploy/vps
docker compose -f compose.yml build api
docker compose -f compose.yml up -d database api
docker compose -f compose.yml ps
curl -fsS http://127.0.0.1:8765/health
```

Build the Android release with the production endpoint and a private release signing key:

```sh
flutter build apk --release --dart-define=API_URL=https://pns-sysnnova.cloud/stockroom-api
```

Set `NGIGA_KEYSTORE_PATH`, `NGIGA_KEYSTORE_PASSWORD`, `NGIGA_KEY_ALIAS`, and `NGIGA_KEY_PASSWORD` before building. Preserve the signing key and credentials for future app updates.
