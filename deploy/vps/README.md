# Stockroom VPS deployment

The API and MySQL database run in the `ngiga-stockroom` Docker Compose project. The API listens only on `127.0.0.1:8765` on the VPS. Nginx forwards `https://pns-sysnnova.cloud/stockroom-api/` to that loopback port; other applications retain their own routes and containers.

MySQL is reachable only on the project's private Docker network. The API trusts the database container's CA certificate, mounted from `/opt/ngiga-stockroom/mysql-ca.pem`. The mobile app communicates with Nginx over HTTPS.

The deployment uses a private `.env` file beside `compose.yml`. Supply `MYSQL_ROOT_PASSWORD`, `MYSQL_PASSWORD`, `SECRET_KEY`, `ADMIN_EMAIL`, `ADMIN_PASSWORD`, `SMTP_USERNAME`, and `SMTP_PASSWORD`. Use a Gmail app password for SMTP and keep this file out of Git.

Password reset emails link to the public API's `/auth/password-reset/page` form. Set `PUBLIC_API_URL` if the HTTPS API address differs from `https://pns-sysnnova.cloud/stockroom-api`. Reset links expire after 10 minutes and can be used once.
Verification and reset messages include a branded HTML design and a plain-text alternative. Password reset requests within one minute return a clear cooldown error, so the app does not claim to have sent another link.

Deploy from `/opt/ngiga-stockroom/deploy/vps` on the VPS:

```sh
cd /opt/ngiga-stockroom/deploy/vps
sh ./prepare-mysql-tls.sh
docker compose -f compose.yml build api
docker compose -f compose.yml up -d api
docker compose -f compose.yml ps
curl -fsS http://127.0.0.1:8765/health
```

Add `nginx-location.conf` to the existing HTTPS server block with an `include` directive, run `nginx -t`, then gracefully reload Nginx. Keep a copy of the original Nginx configuration before editing it.

Build the Android release with the production endpoint and a private release signing key:

```sh
flutter build apk --release --dart-define=API_URL=https://pns-sysnnova.cloud/stockroom-api
```

Set `NGIGA_KEYSTORE_PATH`, `NGIGA_KEYSTORE_PASSWORD`, `NGIGA_KEY_ALIAS`, and `NGIGA_KEY_PASSWORD` before building. Preserve the signing key and credentials for future app updates.
