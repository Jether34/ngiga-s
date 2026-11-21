# Stockroom Campus Inventory

Flutter client for Android, iOS, and desktop. The client has been exercised on
the Android emulator against the C++/Drogon API and MySQL database. The original
FastAPI/SQLite service remains in `backend/main.py` as a legacy fallback; choose
the API address at launch with `API_URL`.

## Run on this Windows PC

The local MySQL service uses the settings in the ignored `backend/.env`. Start
the C++ API on port 8000:

```powershell
cmake -S backend/cpp -B backend/cpp/build `
  -DCMAKE_TOOLCHAIN_FILE="$env:USERPROFILE/dev/vcpkg/scripts/buildsystems/vcpkg.cmake" `
  -DVCPKG_TARGET_TRIPLET=x64-windows
cmake --build backend/cpp/build --config Release
powershell.exe -NoProfile -ExecutionPolicy Bypass -File backend/cpp/run-local.ps1
```

Run or reinstall the mobile app against that API:

```powershell
flutter pub get
flutter run -d emulator-5554 --dart-define=API_URL=http://10.0.2.2:8000
```

The emulator reaches the PC through `10.0.2.2`. Set `SMTP_USERNAME` and
`SMTP_PASSWORD` in the private server environment before student sign-up.
The admin account is seeded from `ADMIN_EMAIL`, `ADMIN_PASSWORD`, `ADMIN_NAME`,
and `ADMIN_ID` when the MySQL database has no administrator. Public sign-up
creates a STUDENT and sends a six-digit code to the supplied email, including
when a phone number is used. A verified student gets another email challenge
when signing in from a new IP. Codes expire after 10 minutes and allow five
attempts. Existing MySQL databases get the additional columns when the C++ API
starts. Android schedules a reminder before a loan is due and repeats overdue
reminders every three hours until the app learns that the item was returned;
the silent setting controls their sound.

## API and data

`backend/mysql/schema.sql` defines users, equipment types, physical units, loans,
receipts, inventory transactions, and the transactional event outbox. Stock
quantities are derived from physical-unit statuses. Unique serials and the
active-loan index prevent duplicate issuance. Loan, ISSUE transaction, receipt,
and stock changes run in one MySQL transaction. Returns create the linked
RECEIVE transaction. Each API replica polls the outbox and notifies its connected
admin WebSocket clients.

The C++ API includes:

- `POST /auth/signup`, `POST /auth/login`, `POST /auth/verify`, `GET /me`
- `GET /equipment`, `GET /equipment/{id}`, `GET /units/{barcode}`
- `POST/PATCH/DELETE /equipment`, `PATCH /equipment/{id}/photo`, `POST /equipment/{id}/units`, `PATCH /units/{id}/status`
- `POST /loans`, `POST /returns/{barcode}`, `GET /receipts`
- `GET /transactions`, `GET /reports/low-stock`, `WS /events?token=...`
- `GET /health`

## MySQL and Nginx deployment

`docker-compose.yml` defines MySQL, two C++ API replicas, and an Nginx load
balancer. Set the variables from `backend/.env`, then run:

```powershell
docker compose --env-file backend/.env up --build
```

The load balancer listens on port 8080 and supports WebSocket upgrades. The
compose file initializes a new MySQL volume from the schema; existing database
contents need to be imported separately before replacing a populated service.

## Current scope

The C++/MySQL Android flow has been checked for login, barcode lookup, due-date
selection before scanning, borrow confirmation, receipt PDF sharing, return,
admin loan/return WebSocket notifications, and concurrent attempts to issue the
same unit. One concurrent request succeeds and the other receives HTTP 409.

Durable offline admin inventory queues, email delivery, and a C++ implementation
of the legacy bulk `POST /transactions` endpoint are not included yet. Borrowing
and returns are online-only. The Python/SQLite fallback is unchanged.
