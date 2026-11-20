# C++ API migration

This directory is the C++/Drogon replacement service. It connects to the MySQL
schema in `../mysql/schema.sql`; local credentials come from `backend/.env` and
must not be committed.

## Build on Windows

Install Visual Studio C++ Build Tools, CMake, and vcpkg, then run:

```powershell
cmake -S backend/cpp -B backend/cpp/build `
  -DCMAKE_TOOLCHAIN_FILE="$env:USERPROFILE/dev/vcpkg/scripts/buildsystems/vcpkg.cmake" `
  -DVCPKG_TARGET_TRIPLET=x64-windows
cmake --build backend/cpp/build --config Release
./backend/cpp/run-local.ps1
```

The service supports login/signup, account identity, inventory reads and
management, exact serial lookup, transactional borrow/return, receipts,
transaction history, low-stock reports, and admin WebSocket events. The Flutter
Android client has been exercised against it on this PC. The legacy bulk
`POST /transactions` route and offline admin change queue still live only in the
Python service.
