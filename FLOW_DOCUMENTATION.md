# City Runner Flow Documentation

## Overview

City Runner is now a multi-role bus tracking system with three user experiences:

- `User`: sees live buses on the Gangtok → Ranipool route, live seat availability, ETA, and the real Sikkim route map.
- `Driver`: logs in on their phone, grants GPS permission, updates the assigned bus location from that phone, and manages seats for that bus.
- `Admin`: logs in with a bootstrap admin account, creates buses, provisions driver accounts, resets driver passwords, and monitors all live buses.

## Core Architecture

### Current folders

- [backend](/c:/Users/saiim/OneDrive/Desktop/City_Runner/backend): FastAPI backend and SQLite-backed data model.
- [cityrunner_app](/c:/Users/saiim/OneDrive/Desktop/City_Runner/cityrunner_app): active Flutter frontend.
- The old root Next.js frontend files were removed because the current version uses Flutter.

### Flutter App

- Flutter app folder: [cityrunner_app](/c:/Users/saiim/OneDrive/Desktop/City_Runner/cityrunner_app)
- HTTP client: [cityrunner_app/lib/services/api_service.dart](/c:/Users/saiim/OneDrive/Desktop/City_Runner/cityrunner_app/lib/services/api_service.dart)
- API repository: [cityrunner_app/lib/repositories/city_runner_repository.dart](/c:/Users/saiim/OneDrive/Desktop/City_Runner/cityrunner_app/lib/repositories/city_runner_repository.dart)
- App state: [cityrunner_app/lib/providers/app_provider.dart](/c:/Users/saiim/OneDrive/Desktop/City_Runner/cityrunner_app/lib/providers/app_provider.dart)
- Token storage: [cityrunner_app/lib/services/token_store.dart](/c:/Users/saiim/OneDrive/Desktop/City_Runner/cityrunner_app/lib/services/token_store.dart)
- Screens include passenger home, tracking, read-only passenger seat view, driver dashboard, and admin dashboard.

The Flutter app is now the active frontend. It calls the FastAPI backend with `Dio`, uses a small repository layer, manages state with `Provider` / `ChangeNotifier`, and stores driver/admin bearer tokens with `flutter_secure_storage`.

Flutter backend URL selection:

- Flutter web, desktop, and iOS simulator default to `http://localhost:8000`
- Android emulator defaults to `http://10.0.2.2:8000`
- Physical phones should use `--dart-define=CITY_RUNNER_API_BASE_URL=http://YOUR-PC-IP:8000`

### Backend

- `FastAPI`
- `SQLite`
- `SQLAlchemy`
- Database setup: [backend/bus_tracker/db.py](/c:/Users/saiim/OneDrive/Desktop/City_Runner/backend/bus_tracker/db.py)
- ORM entities: [backend/bus_tracker/entities.py](/c:/Users/saiim/OneDrive/Desktop/City_Runner/backend/bus_tracker/entities.py)
- API schemas: [backend/bus_tracker/models.py](/c:/Users/saiim/OneDrive/Desktop/City_Runner/backend/bus_tracker/models.py)
- Auth helpers: [backend/bus_tracker/security.py](/c:/Users/saiim/OneDrive/Desktop/City_Runner/backend/bus_tracker/security.py)
- Route and seat templates: [backend/bus_tracker/state.py](/c:/Users/saiim/OneDrive/Desktop/City_Runner/backend/bus_tracker/state.py)
- Main API: [backend/main.py](/c:/Users/saiim/OneDrive/Desktop/City_Runner/backend/main.py)

## Authentication Flow

### Admin bootstrap

Admin credentials are not hardcoded in the source.

On backend startup:

1. The app checks whether any admin user exists.
2. If no admin exists, it reads:
   - `CITY_RUNNER_ADMIN_USERNAME`
   - `CITY_RUNNER_ADMIN_PASSWORD`
   - `CITY_RUNNER_ADMIN_NAME` optional
3. If `CITY_RUNNER_ADMIN_USERNAME` or `CITY_RUNNER_ADMIN_PASSWORD` is missing and no admin exists yet, backend startup fails with a clear setup error.
4. The backend creates the first admin account and stores only a salted password hash.

### Password storage

Passwords are not stored in plain text.

The app uses:

- `PBKDF2-HMAC-SHA256`
- random per-user salt
- stored fields:
  - `password_hash`
  - `password_salt`

This is password hashing, not reversible encryption. That is the correct pattern for user passwords. Full database-at-rest encryption would be added separately at infrastructure level in a production deployment.

### Session flow

1. Driver or admin logs in using `/api/auth/login`.
2. Backend verifies the hashed password.
3. Backend creates a random session token.
4. Only the token hash is stored in `auth_sessions`.
5. The Flutter app stores the plain token with `flutter_secure_storage`.
6. Future protected calls send `Authorization: Bearer <token>`.
7. Driver or admin logs out using `/api/auth/logout`.
8. Backend hashes the presented bearer token, deletes the matching `auth_sessions` row, and the Flutter app clears its local token.
9. In Flutter, a `401` response clears the affected token and redirects the driver/admin back to login.

## GPS / Live Location Flow

### Driver phone as bus tracker

This is the main live tracking flow:

1. Driver opens the Flutter app on their phone.
2. Driver logs into the `Driver` view.
3. The mobile app asks for GPS permission.
4. The Flutter app starts a `Geolocator` position stream.
5. Each accepted position is sent to `/api/driver/location`.
6. Backend updates the assigned bus:
   - `last_lat`
   - `last_lng`
   - `last_accuracy_meters`
   - `location_updated_at`
7. User and admin views poll the backend and render that updated location on the same Sikkim route map.

### What users see

Users do not generate the bus location.

Users only:

- view live bus positions
- optionally share their own location locally for distance-to-bus calculations
- see ETA and stop progress based on the driver-fed live coordinates
- see the same live bus location in the Flutter tracking UI

### Map behavior

The Flutter map/tracking UI is shared across:

- `User` view
- `Driver` view
- `Admin` view

It uses the same backend bus state and shows:

- live bus marker positions
- route polyline
- stop markers
- optional viewer location marker

The driver remains the source of truth for the bus GPS. User and admin are read-only viewers of that same live location data.

## Bus Management Flow

### Add a bus

Admin creates a bus with:

- bus name
- registration number
- route name

When a bus is created, the backend automatically seeds:

- the Gangtok → Ranipool stop list
- the full 17-seat template
- the Sikkim route polyline used on the map

### Create a driver

Admin creates a driver with:

- display name
- username
- initial password
- optional bus assignment

If a bus assignment is provided, the backend verifies:

- the bus exists
- no existing driver is already assigned to that bus

This prevents two driver accounts from being assigned to the same bus.

The initial password is hashed before storage.

The new driver account is marked:

- `must_change_password = true`

That flag shows up in the driver UI and admin UI.

### Reset a driver password

Admin can reset a driver password from the admin panel.

After reset:

- the new password is hashed
- `must_change_password` is set to `true` again
- existing sessions for that driver are revoked, so the driver must log in again with the reset password

### Remove a driver

Admin can remove a driver account after confirming the admin password.

Before deletion, the backend explicitly removes that driver's active sessions.

## Seat Management Flow

### User

- can see seat map
- cannot change seats
- Flutter currently shows this as a read-only passenger seat view because there is no passenger booking endpoint yet.

### Driver

- can toggle seats for the assigned bus only
- can reset all seats for the assigned bus
- can toggle active/inactive status for the assigned bus

Seat data is stored per bus in the `seats` table.

## Route / ETA Logic

The route geometry is stored as a real Sikkim polyline for the Gangtok → Ranipool corridor.

Stops currently include:

1. Gangtok
2. Tadong
3. 6th Mile
4. Boomtar
5. Singtam Turn
6. Ranipool

ETA is currently estimated by:

1. calculating distance from the live bus coordinate to the final stop
2. applying a demo average road speed

Current stop is estimated by nearest configured stop.

## Database Tables

### `buses`

- base bus identity
- route name
- route polyline
- active/inactive state
- last live GPS fields

### `bus_stops`

- stop name
- coordinates
- fare
- order along the route

### `seats`

- one row per physical seat
- seat code
- row/column position
- booked/free state

### `users`

- admin and driver accounts
- hashed password + salt
- role
- assigned bus
- must-change-password flag

### `auth_sessions`

- hashed session token
- linked user
- expiry

## Main API Endpoints

### Public

- `GET /api/public/buses`

### Shared auth

- `POST /api/auth/login`
- `POST /api/auth/logout`
- `GET /api/auth/me`
- `POST /api/auth/change-password`

### Driver

- `GET /api/driver/dashboard`
- `POST /api/driver/location`
- `POST /api/driver/seats/{seat_id}/toggle`
- `POST /api/driver/seats/reset`
- `POST /api/driver/bus/toggle-active`

### Admin

- `GET /api/admin/overview`
- `POST /api/admin/buses`
- `POST /api/admin/drivers`
- `POST /api/admin/drivers/{driver_id}/reset-password`
- `DELETE /api/admin/drivers/{driver_id}`

## Debugging Checklist

### Driver can log in but location does not update

Check:

- driver account has an assigned bus
- phone GPS permission is allowed
- backend is reachable from the phone
- `/api/driver/location` is returning success
- `location_updated_at` changes in the database

### Admin login does not work

Check:

- backend was started with `CITY_RUNNER_ADMIN_USERNAME` and `CITY_RUNNER_ADMIN_PASSWORD`
- the database did not already contain an admin with different credentials

### Bus does not appear live for users

Check:

- driver is logged in
- driver phone is sending GPS updates
- bus `last_lat` and `last_lng` are populated
- `location_updated_at` is recent enough to count as live

### Seats do not update in UI

Check:

- driver is assigned to that bus
- seat toggle endpoint succeeds
- frontend refreshes the public and driver/admin data after mutation

### Flutter app cannot reach the backend

Check:

- backend is running on port `8000`
- Android emulator is using `http://10.0.2.2:8000`
- Flutter web, iOS simulator, and desktop are using `http://localhost:8000`
- physical phone is using `--dart-define=CITY_RUNNER_API_BASE_URL=http://YOUR-PC-IP:8000`
- backend is bound to the LAN when testing from a physical phone
- Android cleartext traffic and location permissions are present in the main manifest
- iOS location and local-network permission text exists in `Info.plist`
- `GET /api/public/buses` returns data from the backend

### Flutter dependency checks

The Flutter app depends on `flutter_secure_storage`. After pulling these changes, run:

```powershell
cd cityrunner_app
flutter pub get
flutter analyze
```

Current local verification:

- Flutter SDK installed at `C:\Users\saiim\development\flutter`
- `C:\Users\saiim\development\flutter\bin` added to the user `PATH`
- `flutter pub get` completed successfully
- `flutter analyze` reports no issues
- `flutter build web` completes successfully and writes `cityrunner_app/build/web`

Environment notes:

- Android emulator/device builds still need Android Studio and the Android SDK installed.
- Windows desktop plugin builds need Windows Developer Mode plus Visual Studio C++; Windows desktop is currently disabled with `flutter config --no-enable-windows-desktop` so mobile/web dependency checks work.
- Flutter's web build currently emits WebAssembly dry-run warnings from `flutter_secure_storage_web`, but the normal JavaScript web build succeeds.

If PowerShell still reports `flutter` as unrecognized after installation, the open terminal has not picked up the updated user `PATH` yet. Restart the terminal, or run:

```powershell
$env:Path = "$env:USERPROFILE\development\flutter\bin;$env:Path"
flutter run -d chrome
```

You can also call Flutter directly:

```powershell
& "$env:USERPROFILE\development\flutter\bin\flutter.bat" run -d chrome
```

## Current Scope and Honest Limitations

- The system is now multi-bus and multi-role.
- Passwords are securely hashed and salted.
- Logout now revokes the active backend session instead of only clearing local storage.
- Flutter stores driver/admin tokens with `flutter_secure_storage` and redirects to login on expired sessions.
- The database is SQLite for local/demo scale.
- The route template is currently focused on Gangtok → Ranipool.
- Full production-grade database encryption at rest is not implemented inside SQLite itself.
- There is no websocket layer yet; views refresh by polling.
- The Flutter app imports `google_maps_flutter`; mobile map rendering still needs platform Maps API keys for real device builds.
- Passenger booking is not implemented in the backend yet. Passengers can view seats, while drivers can mutate seat state.
- The app currently depends on polling rather than server-streamed live state.

## Suggested Next Scaling Steps

1. Move from polling to websockets for live location and seat events.
2. Migrate from SQLite to PostgreSQL.
3. Add route management so admin can define different stop sets and polylines.
4. Add audit logs for admin actions.
5. Add richer session/device management for viewing and revoking other active sessions.
