# City Runner

City Runner is a multi-role bus tracking and seat management system for the Gangtok → Ranipool route in Sikkim.

## Stack

- Mobile frontend: Flutter app in `cityrunner_app`, Dio, Provider, flutter_secure_storage
- Backend: FastAPI, SQLAlchemy, SQLite
- Auth: database-backed admin and driver login
- Password security: salted PBKDF2 password hashing

## Roles

- `User`: views live buses, route stops, ETA, fare list, and seat availability
- `Driver`: logs in on their phone, shares live GPS, manages seats, and updates bus status
- `Admin`: creates buses, provisions drivers, resets passwords, and monitors the fleet

## Project Layout

- `backend`: FastAPI app, SQLAlchemy models, SQLite database, auth/session logic, and REST endpoints
- `cityrunner_app`: active Flutter frontend for passenger, driver, and admin flows
- `FLOW_DOCUMENTATION.md`: detailed flow notes for auth, GPS tracking, seats, and admin operations

The old root Next.js frontend has been removed. The Flutter app is now the frontend for the current version.

## First-Time Setup

Use `.env.example` as a reference and set these environment variables before the first backend startup:

```bash
CITY_RUNNER_ADMIN_USERNAME=admin
CITY_RUNNER_ADMIN_PASSWORD=cityrunner
CITY_RUNNER_ADMIN_NAME=City Runner Admin
```

The first admin account is created on backend startup only if no admin exists yet. `CITY_RUNNER_ADMIN_USERNAME` and `CITY_RUNNER_ADMIN_PASSWORD` are required for that first startup; the backend does not create default admin credentials.

## Run The Backend

For Command Prompt (cmd.exe):

```bat
cd backend
python -m pip install -r requirements.txt
set CITY_RUNNER_ADMIN_USERNAME=admin
set CITY_RUNNER_ADMIN_PASSWORD=cityrunner
set CITY_RUNNER_ADMIN_NAME=City Runner Admin
python -m uvicorn main:app --reload --port 8000
```

For PowerShell:

```powershell
cd backend
python -m pip install -r requirements.txt
$env:CITY_RUNNER_ADMIN_USERNAME="admin"
$env:CITY_RUNNER_ADMIN_PASSWORD="cityrunner"
$env:CITY_RUNNER_ADMIN_NAME="City Runner Admin"
python -m uvicorn main:app --reload --port 8000
```

The `set` syntax is for Command Prompt; PowerShell requires `$env:NAME="value"` and quoted values when the value contains spaces.

## Run The Flutter App

The Flutter app lives in:

```text
cityrunner_app
```

Install dependencies and run it:

```powershell
cd cityrunner_app
flutter pub get
flutter run -d chrome
```

On this Windows machine, Flutter is installed at `C:\Users\saiim\development\flutter`
and `C:\Users\saiim\development\flutter\bin` has been added to the user `PATH`.
Restart open terminals/editors if `flutter` is still not recognized.

If the current PowerShell terminal still says `flutter` is not recognized, use one of these:

```powershell
$env:Path = "$env:USERPROFILE\development\flutter\bin;$env:Path"
flutter run -d chrome
```

```powershell
& "$env:USERPROFILE\development\flutter\bin\flutter.bat" run -d chrome
```

Backend URL behavior:

- Flutter web, desktop, and iOS simulator default to `http://localhost:8000`
- Android emulator defaults to `http://10.0.2.2:8000`
- Physical phones should pass your computer's LAN IP:

```powershell
flutter run --dart-define=CITY_RUNNER_API_BASE_URL=http://YOUR-PC-IP:8000
```

When testing from a physical phone, start the backend on the LAN from the `backend` directory:

```powershell
cd ..\backend
python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

## Current Features

- Real Sikkim route map for Gangtok → Ranipool
- Driver phone GPS becomes the live bus location source
- User, driver, and admin map views
- Flutter passenger, driver, and admin screens wired to the FastAPI backend
- Database-backed buses, drivers, seats, and sessions
- Bearer session tokens stored securely in Flutter with `flutter_secure_storage`
- Flutter redirects driver/admin users back to login when a session expires
- Admin-managed driver onboarding and password reset
- Admin password reset and driver removal revoke that driver's active sessions
- Backend prevents assigning the same bus to more than one driver
- Driver self-service password change

## Verification

These checks passed locally after the Flutter setup:

```powershell
cd cityrunner_app
flutter pub get
flutter analyze
flutter build web
```

## Current Limitations

- Passenger booking is not implemented in the backend yet. Passengers can view seats; drivers can toggle seat status.
- Flutter mobile map rendering uses `google_maps_flutter`, so real mobile builds may need platform Maps API keys.
- Android emulator/device builds still need Android Studio and the Android SDK installed.
- Windows desktop plugin builds need Windows Developer Mode plus Visual Studio C++; Windows desktop is currently disabled with `flutter config --no-enable-windows-desktop` so `flutter pub get` can run for mobile/web work.
- `flutter pub get`, `flutter analyze`, and `flutter build web` pass with Flutter `3.44.5`.
- Flutter's web build currently emits WebAssembly dry-run warnings from `flutter_secure_storage_web`, but the normal JavaScript web build succeeds.
# cityrunner__
