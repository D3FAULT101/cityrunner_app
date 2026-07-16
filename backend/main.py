from __future__ import annotations

import asyncio
from datetime import datetime
from functools import lru_cache
import os
import secrets
from datetime import timedelta
from typing import Annotated

from fastapi import Depends, FastAPI, Header, HTTPException, Query, WebSocket, WebSocketDisconnect, status
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import delete, inspect, select, text, update
from sqlalchemy.orm import Session, joinedload, selectinload

from bus_tracker.db import Base, SessionLocal, engine
from bus_tracker.entities import (
    AuthSession,
    Booking,
    BookingSeat,
    Bus,
    BusStop,
    NotificationRecord,
    OtpChallenge,
    PassengerAccount,
    Seat,
    User,
)
from bus_tracker.models import (
    AdminOverviewResponse,
    BookingCreateRequest,
    BookingResponse,
    BookingRespondRequest,
    BookingSeatResponse,
    BusCreateRequest,
    BusResponse,
    ChangePasswordRequest,
    Coordinate,
    DriverCreateRequest,
    DriverDashboardResponse,
    DriverLocationUpdateRequest,
    DriverRemoveRequest,
    DriverPasswordResetRequest,
    DriverSummaryResponse,
    LoginRequest,
    LoginResponse,
    MutationResponse,
    OtpRequest,
    OtpRequestResponse,
    OtpVerifyRequest,
    PassengerAccountResponse,
    PassengerLoginResponse,
    NotificationListResponse,
    NotificationResponse,
    PublicOverviewResponse,
    SeatResponse,
    StopResponse,
    UserSessionResponse,
)
from bus_tracker.security import (
    create_password_record,
    create_session_token,
    generate_booking_code,
    hash_session_token,
    verify_password,
)
from bus_tracker.state import (
    DEFAULT_ROUTE_NAME,
    ROUTE_STOPS,
    SEAT_LAYOUT_TEMPLATE,
    cumulative_fares,
    default_route_polyline_json,
    estimate_eta_minutes,
    fare_between_stops,
    get_current_stop_index,
    haversine_distance_km,
    location_is_fresh,
    parse_route_polyline,
)
from bus_tracker.ws import manager


app = FastAPI(title="City Runner Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)



def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


DbSession = Annotated[Session, Depends(get_db)]


@lru_cache(maxsize=64)
def parse_route_polyline_cached(route_polyline_json: str) -> tuple[Coordinate, ...]:
    return tuple(parse_route_polyline(route_polyline_json))


def create_bus_bundle(db: Session, name: str, registration_number: str, route_name: str = DEFAULT_ROUTE_NAME) -> Bus:
    bus = Bus(
        name=name,
        registration_number=registration_number,
        route_name=route_name,
        route_polyline_json=default_route_polyline_json(),
        seat_capacity=len(SEAT_LAYOUT_TEMPLATE),
        is_active=True,
    )
    db.add(bus)
    db.flush()

    db.add_all(
        [
            BusStop(
                bus_id=bus.id,
                name=stop["name"],
                lat=stop["lat"],
                lng=stop["lng"],
                fare=stop["fare"],
                order_index=order_index,
            )
            for order_index, stop in enumerate(ROUTE_STOPS)
        ]
    )

    db.add_all(
        [
            Seat(
                bus_id=bus.id,
                seat_code=seat_code,
                label=label,
                row_number=row_number,
                column_name=column_name,
                is_booked=False,
            )
            for seat_code, label, row_number, column_name in SEAT_LAYOUT_TEMPLATE
        ]
    )

    db.flush()
    return bus


def ensure_seed_data() -> None:
    Base.metadata.create_all(bind=engine)
    # Existing local SQLite databases predate passenger auth.  SQLite's
    # create_all does not add columns, so keep this tiny additive migration
    # until the project adopts a dedicated migration tool.
    session_columns = inspect(engine).get_columns("auth_sessions")
    columns = {column["name"] for column in session_columns}
    with engine.begin() as connection:
        # Older databases made user_id mandatory. Rebuild this one small table
        # so a session can instead belong to a passenger account.
        user_id_column = next(column for column in session_columns if column["name"] == "user_id")
        if not user_id_column["nullable"]:
            connection.execute(text("PRAGMA foreign_keys=OFF"))
            connection.execute(text("CREATE TABLE auth_sessions_new (id INTEGER NOT NULL PRIMARY KEY, token_hash VARCHAR(128) NOT NULL UNIQUE, user_id INTEGER, passenger_id INTEGER, expires_at DATETIME NOT NULL, created_at DATETIME NOT NULL)"))
            connection.execute(text("INSERT INTO auth_sessions_new (id, token_hash, user_id, expires_at, created_at) SELECT id, token_hash, user_id, expires_at, created_at FROM auth_sessions"))
            connection.execute(text("DROP TABLE auth_sessions"))
            connection.execute(text("ALTER TABLE auth_sessions_new RENAME TO auth_sessions"))
            connection.execute(text("CREATE INDEX ix_auth_sessions_token_hash ON auth_sessions (token_hash)"))
            connection.execute(text("PRAGMA foreign_keys=ON"))
        if "passenger_id" not in columns:
            connection.execute(text("ALTER TABLE auth_sessions ADD COLUMN passenger_id INTEGER"))
        booking_columns = {column["name"] for column in inspect(engine).get_columns("bookings")}
        if "passenger_id" not in booking_columns:
            connection.execute(text("ALTER TABLE bookings ADD COLUMN passenger_id INTEGER"))
    with SessionLocal() as db:
        default_bus = db.scalar(select(Bus).limit(1))
        if default_bus is None:
            create_bus_bundle(db, "City Runner 17", "SK-01-CR-17")
            db.commit()

        admin_exists = db.scalar(select(User).where(User.role == "admin").limit(1))
        admin_username = os.getenv("CITY_RUNNER_ADMIN_USERNAME")
        admin_password = os.getenv("CITY_RUNNER_ADMIN_PASSWORD")
        admin_name = os.getenv("CITY_RUNNER_ADMIN_NAME", "City Runner Admin")
        if admin_exists is None and (not admin_username or not admin_password):
            raise RuntimeError(
                "No admin account exists. Set CITY_RUNNER_ADMIN_USERNAME and "
                "CITY_RUNNER_ADMIN_PASSWORD before starting the backend."
            )

        if admin_exists is None and admin_username and admin_password:
            password_hash, password_salt = create_password_record(admin_password)
            db.add(
                User(
                    username=admin_username,
                    display_name=admin_name,
                    role="admin",
                    password_hash=password_hash,
                    password_salt=password_salt,
                    is_active=True,
                    must_change_password=False,
                )
            )
            db.commit()


@app.on_event("startup")
async def on_startup() -> None:
    ensure_seed_data()
    manager.bind_loop(asyncio.get_running_loop())


def build_user_session(user: User) -> UserSessionResponse:
    return UserSessionResponse(
        id=user.id,
        username=user.username,
        display_name=user.display_name,
        role=user.role,  # type: ignore[arg-type]
        assigned_bus_id=user.assigned_bus_id,
        must_change_password=user.must_change_password,
    )


def build_driver_summary(user: User, assigned_bus_name: str | None = None) -> DriverSummaryResponse:
    if assigned_bus_name is None:
        assigned_bus = user.assigned_bus
        assigned_bus_name = assigned_bus.name if assigned_bus else None
    return DriverSummaryResponse(
        id=user.id,
        username=user.username,
        display_name=user.display_name,
        is_active=user.is_active,
        must_change_password=user.must_change_password,
        assigned_bus_id=user.assigned_bus_id,
        assigned_bus_name=assigned_bus_name,
    )


def build_bus_response(bus: Bus) -> BusResponse:
    route = list(parse_route_polyline_cached(bus.route_polyline_json))
    bus_stops = list(bus.stops)
    bus_seats = list(bus.seats)
    stop_responses = [
        StopResponse(
            id=stop.id,
            name=stop.name,
            coordinate=Coordinate(lat=stop.lat, lng=stop.lng),
            fare=stop.fare,
            order_index=stop.order_index,
        )
        for stop in bus_stops
    ]
    seat_responses = []
    available_seats = 0
    for seat in bus_seats:
        if not seat.is_booked:
            available_seats += 1
        seat_responses.append(
            SeatResponse(
                id=seat.id,
                seat_code=seat.seat_code,
                label=seat.label,
                row_number=seat.row_number,
                column_name=seat.column_name,
                is_booked=seat.is_booked,
            )
        )
    assigned_driver = next((driver for driver in bus.drivers if driver.role == "driver"), None)

    current_stop_index = None
    eta_minutes = None
    position = None
    if bus.last_lat is not None and bus.last_lng is not None and bus_stops:
        position = Coordinate(lat=bus.last_lat, lng=bus.last_lng)
        stop_pairs = [(stop.lat, stop.lng) for stop in bus_stops]
        current_stop_index = get_current_stop_index(bus.last_lat, bus.last_lng, stop_pairs)
        destination = bus_stops[-1]
        eta_minutes = estimate_eta_minutes(bus.last_lat, bus.last_lng, destination.lat, destination.lng)

    return BusResponse(
        id=bus.id,
        name=bus.name,
        registration_number=bus.registration_number,
        route_name=bus.route_name,
        seat_capacity=bus.seat_capacity,
        is_active=bus.is_active,
        current_stop_index=current_stop_index,
        eta_minutes=eta_minutes,
        available_seats=available_seats,
        has_live_location=location_is_fresh(bus.location_updated_at),
        location_updated_at=bus.location_updated_at,
        position=position,
        route=route,
        stops=stop_responses,
        seats=seat_responses,
        assigned_driver=build_driver_summary(assigned_driver, bus.name) if assigned_driver else None,
    )


def get_buses_with_relations(db: Session) -> list[Bus]:
    return list(
        db.scalars(
            select(Bus)
            .options(
                selectinload(Bus.stops),
                selectinload(Bus.seats),
                selectinload(Bus.drivers),
            )
            .order_by(Bus.id)
        )
    )


def get_bus_with_relations(db: Session, bus_id: int) -> Bus | None:
    return db.scalar(
        select(Bus)
        .options(selectinload(Bus.stops), selectinload(Bus.seats), selectinload(Bus.drivers))
        .where(Bus.id == bus_id)
    )


def broadcast_bus_changed(db: Session, bus_id: int) -> None:
    """Call after committing any change to a bus (location, seats,
    active status) so every connected passenger/admin screen updates
    instantly instead of waiting for their next poll."""
    bus = get_bus_with_relations(db, bus_id)
    if bus is None:
        return
    payload = build_bus_response(bus).model_dump(mode="json")
    manager.broadcast_public({"type": "bus_updated", "bus": payload})
    manager.broadcast_admin({"type": "bus_updated", "bus": payload})
    assigned_driver_id = next((driver.id for driver in bus.drivers if driver.role == "driver"), None)
    if assigned_driver_id is not None:
        manager.broadcast_driver(assigned_driver_id, {"type": "bus_updated", "bus": payload})


def broadcast_admin_fleet_changed(db: Session) -> None:
    """Call after admin actions that change the fleet/driver roster shape
    (new bus, new driver, driver removed) so the admin dashboard's Fleet
    and Drivers lists refresh instantly."""
    buses = [build_bus_response(bus).model_dump(mode="json") for bus in get_buses_with_relations(db)]
    drivers = list(
        db.scalars(
            select(User).options(joinedload(User.assigned_bus)).where(User.role == "driver").order_by(User.id)
        )
    )
    driver_payloads = [build_driver_summary(driver).model_dump(mode="json") for driver in drivers]
    manager.broadcast_admin({"type": "admin_overview_updated", "buses": buses, "drivers": driver_payloads})
    manager.broadcast_public({"type": "buses_updated", "buses": buses})


def require_authenticated_user(
    db: DbSession,
    authorization: Annotated[str | None, Header()] = None,
) -> User:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Authentication required.")

    raw_token = authorization.removeprefix("Bearer ").strip()
    session = db.scalar(
        select(AuthSession)
        .options(joinedload(AuthSession.user).joinedload(User.assigned_bus))
        .where(AuthSession.token_hash == hash_session_token(raw_token))
    )
    if session is None or session.user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid session.")
    if session.expires_at <= datetime.utcnow():
        db.delete(session)
        db.commit()
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Session expired.")
    if not session.user.is_active:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Inactive account.")
    return session.user


def require_driver(user: Annotated[User, Depends(require_authenticated_user)]) -> User:
    if user.role != "driver":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Driver access required.")
    return user


def require_admin(user: Annotated[User, Depends(require_authenticated_user)]) -> User:
    if user.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin access required.")
    return user


def _session_for_token(db: Session, authorization: str | None) -> AuthSession | None:
    if not authorization or not authorization.startswith("Bearer "):
        return None
    raw_token = authorization.removeprefix("Bearer ").strip()
    return db.scalar(
        select(AuthSession)
        .options(joinedload(AuthSession.passenger))
        .where(AuthSession.token_hash == hash_session_token(raw_token))
    )


def require_passenger(
    db: DbSession,
    authorization: Annotated[str | None, Header()] = None,
) -> PassengerAccount:
    session = _session_for_token(db, authorization)
    if session is None or session.passenger is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Passenger authentication required.")
    if session.expires_at <= datetime.utcnow():
        db.delete(session)
        db.commit()
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Session expired.")
    return session.passenger


@app.get("/api/public/buses", response_model=PublicOverviewResponse)
def get_public_buses(db: DbSession) -> PublicOverviewResponse:
    buses = [build_bus_response(bus) for bus in get_buses_with_relations(db)]
    return PublicOverviewResponse(buses=buses)


@app.post("/api/auth/login", response_model=LoginResponse)
def login(request: LoginRequest, db: DbSession) -> LoginResponse:
    user = db.scalar(select(User).where(User.username == request.username))
    if user is None or not verify_password(request.password, user.password_salt, user.password_hash):
        return LoginResponse(success=False, message="Invalid username or password.")
    if not user.is_active:
        return LoginResponse(success=False, message="This account is inactive.")

    token, token_hash, expires_at = create_session_token()
    db.add(AuthSession(token_hash=token_hash, user_id=user.id, expires_at=expires_at))
    db.commit()
    db.refresh(user)
    return LoginResponse(
        success=True,
        message="Login successful.",
        token=token,
        user=build_user_session(user),
    )


def _normalise_phone_number(phone_number: str) -> str:
    cleaned = phone_number.strip().replace(" ", "").replace("-", "")
    if not cleaned.startswith("+"):
        cleaned = f"+{cleaned}"
    if not cleaned[1:].isdigit() or not 7 <= len(cleaned[1:]) <= 15:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Enter a valid phone number.")
    return cleaned


@app.post("/api/auth/otp/request", response_model=OtpRequestResponse)
def request_otp(request: OtpRequest, db: DbSession) -> OtpRequestResponse:
    phone_number = _normalise_phone_number(request.phone_number)
    now = datetime.utcnow()
    recent = db.scalar(
        select(OtpChallenge)
        .where(OtpChallenge.phone_number == phone_number, OtpChallenge.consumed_at.is_(None), OtpChallenge.created_at > now - timedelta(seconds=60))
        .order_by(OtpChallenge.created_at.desc())
    )
    if recent is not None:
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail="Please wait a minute before requesting another code.")
    code = f"{secrets.randbelow(1_000_000):06d}"
    db.add(OtpChallenge(phone_number=phone_number, code_hash=hash_session_token(code), expires_at=now + timedelta(minutes=5)))
    db.commit()
    # TODO: route this through an OtpSender (Twilio/MSG91/etc.) before production.
    dev_code = code if os.getenv("CITY_RUNNER_DEV_OTP") == "1" else None
    return OtpRequestResponse(success=True, message="Verification code sent.", dev_code=dev_code)


@app.post("/api/auth/otp/verify", response_model=PassengerLoginResponse)
def verify_otp(request: OtpVerifyRequest, db: DbSession) -> PassengerLoginResponse:
    phone_number = _normalise_phone_number(request.phone_number)
    challenge = db.scalar(
        select(OtpChallenge)
        .where(OtpChallenge.phone_number == phone_number, OtpChallenge.consumed_at.is_(None), OtpChallenge.expires_at > datetime.utcnow())
        .order_by(OtpChallenge.created_at.desc())
    )
    if challenge is None or challenge.attempts >= 5:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Verification code is invalid or expired.")
    if not secrets.compare_digest(challenge.code_hash, hash_session_token(request.code)):
        challenge.attempts += 1
        db.add(challenge)
        db.commit()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Incorrect verification code.")
    challenge.consumed_at = datetime.utcnow()
    passenger = db.scalar(select(PassengerAccount).where(PassengerAccount.phone_number == phone_number))
    if passenger is None:
        passenger = PassengerAccount(phone_number=phone_number)
        db.add(passenger)
        db.flush()
    token, token_hash, expires_at = create_session_token()
    db.add(challenge)
    db.add(AuthSession(token_hash=token_hash, passenger_id=passenger.id, expires_at=expires_at))
    db.commit()
    return PassengerLoginResponse(success=True, token=token, passenger=PassengerAccountResponse.model_validate(passenger, from_attributes=True))


@app.post("/api/auth/logout", response_model=MutationResponse)
def logout(
    db: DbSession,
    authorization: Annotated[str | None, Header()] = None,
) -> MutationResponse:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Authentication required.")

    raw_token = authorization.removeprefix("Bearer ").strip()
    session = db.scalar(select(AuthSession).where(AuthSession.token_hash == hash_session_token(raw_token)))
    if session is not None:
        db.delete(session)
        db.commit()

    return MutationResponse(success=True, message="Session revoked.")


@app.post("/api/auth/change-password", response_model=MutationResponse)
def change_password(
    request: ChangePasswordRequest,
    db: DbSession,
    user: Annotated[User, Depends(require_authenticated_user)],
) -> MutationResponse:
    if not verify_password(request.current_password, user.password_salt, user.password_hash):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Current password is incorrect.")

    password_hash, password_salt = create_password_record(request.new_password)
    user.password_hash = password_hash
    user.password_salt = password_salt
    user.must_change_password = False
    db.add(user)
    db.commit()
    return MutationResponse(success=True, message="Password updated.")


@app.get("/api/auth/me", response_model=UserSessionResponse)
def get_current_session_user(
    user: Annotated[User, Depends(require_authenticated_user)],
) -> UserSessionResponse:
    return build_user_session(user)


@app.get("/api/passenger/me", response_model=PassengerAccountResponse)
def passenger_me(passenger: Annotated[PassengerAccount, Depends(require_passenger)]) -> PassengerAccountResponse:
    return PassengerAccountResponse.model_validate(passenger, from_attributes=True)


@app.get("/api/driver/dashboard", response_model=DriverDashboardResponse)
def driver_dashboard(
    db: DbSession,
    driver: Annotated[User, Depends(require_driver)],
) -> DriverDashboardResponse:
    bus = None
    if driver.assigned_bus_id is not None:
        bus = db.scalar(
            select(Bus)
            .options(
                selectinload(Bus.stops),
                selectinload(Bus.seats),
                selectinload(Bus.drivers),
            )
            .where(Bus.id == driver.assigned_bus_id)
        )
    return DriverDashboardResponse(
        user=build_user_session(driver),
        bus=build_bus_response(bus) if bus else None,
    )


@app.post("/api/driver/location", response_model=MutationResponse)
def update_driver_location(
    request: DriverLocationUpdateRequest,
    db: DbSession,
    driver: Annotated[User, Depends(require_driver)],
) -> MutationResponse:
    if driver.assigned_bus_id is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No bus is assigned to this driver.")

    bus = db.scalar(select(Bus).where(Bus.id == driver.assigned_bus_id))
    if bus is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Assigned bus not found.")

    bus.last_lat = request.lat
    bus.last_lng = request.lng
    bus.last_accuracy_meters = request.accuracy_meters
    bus.location_updated_at = datetime.utcnow()
    db.add(bus)
    db.commit()
    broadcast_bus_changed(db, bus.id)
    return MutationResponse(success=True, message="Live bus location updated.")


@app.post("/api/driver/seats/{seat_id}/toggle", response_model=MutationResponse)
def toggle_driver_seat(
    seat_id: int,
    db: DbSession,
    driver: Annotated[User, Depends(require_driver)],
) -> MutationResponse:
    if driver.assigned_bus_id is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No bus is assigned to this driver.")

    seat = db.scalar(select(Seat).where(Seat.id == seat_id, Seat.bus_id == driver.assigned_bus_id))
    if seat is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Seat not found.")

    seat.is_booked = not seat.is_booked
    db.add(seat)
    db.commit()
    broadcast_bus_changed(db, driver.assigned_bus_id)
    return MutationResponse(success=True, message=f"{seat.seat_code} updated.")


@app.post("/api/driver/seats/reset", response_model=MutationResponse)
def reset_driver_seats(
    db: DbSession,
    driver: Annotated[User, Depends(require_driver)],
) -> MutationResponse:
    if driver.assigned_bus_id is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No bus is assigned to this driver.")

    db.execute(
        update(Seat)
        .where(Seat.bus_id == driver.assigned_bus_id, Seat.is_booked.is_(True))
        .values(is_booked=False)
    )
    db.commit()
    broadcast_bus_changed(db, driver.assigned_bus_id)
    return MutationResponse(success=True, message="All seats reset to free.")


@app.post("/api/driver/bus/toggle-active", response_model=MutationResponse)
def toggle_driver_bus_status(
    db: DbSession,
    driver: Annotated[User, Depends(require_driver)],
) -> MutationResponse:
    if driver.assigned_bus_id is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No bus is assigned to this driver.")

    bus = db.scalar(select(Bus).where(Bus.id == driver.assigned_bus_id))
    if bus is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Assigned bus not found.")

    bus.is_active = not bus.is_active
    db.add(bus)
    db.commit()
    broadcast_bus_changed(db, bus.id)
    return MutationResponse(success=True, message=f"Bus is now {'active' if bus.is_active else 'inactive'}.")


@app.get("/api/admin/overview", response_model=AdminOverviewResponse)
def get_admin_overview(
    db: DbSession,
    _: Annotated[User, Depends(require_admin)],
) -> AdminOverviewResponse:
    buses = [build_bus_response(bus) for bus in get_buses_with_relations(db)]
    drivers = list(
        db.scalars(
            select(User)
            .options(joinedload(User.assigned_bus))
            .where(User.role == "driver")
            .order_by(User.id)
        )
    )
    return AdminOverviewResponse(
        buses=buses,
        drivers=[build_driver_summary(driver) for driver in drivers],
    )


@app.post("/api/admin/buses", response_model=MutationResponse)
def create_bus(
    request: BusCreateRequest,
    db: DbSession,
    _: Annotated[User, Depends(require_admin)],
) -> MutationResponse:
    existing = db.scalar(select(Bus).where(Bus.registration_number == request.registration_number))
    if existing is not None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Registration number already exists.")

    create_bus_bundle(db, request.name, request.registration_number, request.route_name)
    db.commit()
    broadcast_admin_fleet_changed(db)
    return MutationResponse(success=True, message="New bus added.")


@app.post("/api/admin/drivers", response_model=MutationResponse)
def create_driver(
    request: DriverCreateRequest,
    db: DbSession,
    _: Annotated[User, Depends(require_admin)],
) -> MutationResponse:
    existing = db.scalar(select(User).where(User.username == request.username))
    if existing is not None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Username already exists.")

    if request.assigned_bus_id is not None:
        bus = db.scalar(select(Bus).where(Bus.id == request.assigned_bus_id))
        if bus is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Assigned bus not found.")
        existing_driver = db.scalar(
            select(User).where(User.assigned_bus_id == request.assigned_bus_id, User.role == "driver")
        )
        if existing_driver is not None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="This bus already has a driver assigned.",
            )

    password_hash, password_salt = create_password_record(request.password)
    db.add(
        User(
            username=request.username,
            display_name=request.display_name,
            role="driver",
            password_hash=password_hash,
            password_salt=password_salt,
            is_active=True,
            must_change_password=True,
            assigned_bus_id=request.assigned_bus_id,
        )
    )
    db.commit()
    broadcast_admin_fleet_changed(db)
    return MutationResponse(success=True, message="Driver account created.")


@app.post("/api/admin/drivers/{driver_id}/reset-password", response_model=MutationResponse)
def reset_driver_password(
    driver_id: int,
    request: DriverPasswordResetRequest,
    db: DbSession,
    _: Annotated[User, Depends(require_admin)],
) -> MutationResponse:
    driver = db.scalar(select(User).where(User.id == driver_id, User.role == "driver"))
    if driver is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Driver not found.")

    password_hash, password_salt = create_password_record(request.new_password)
    driver.password_hash = password_hash
    driver.password_salt = password_salt
    driver.must_change_password = True
    db.execute(delete(AuthSession).where(AuthSession.user_id == driver.id))
    db.add(driver)
    db.commit()
    manager.broadcast_driver(driver.id, {"type": "session_revoked", "reason": "Password reset by admin."})
    broadcast_admin_fleet_changed(db)
    return MutationResponse(success=True, message="Driver password reset.")


@app.delete("/api/admin/drivers/{driver_id}", response_model=MutationResponse)
def remove_driver(
    driver_id: int,
    request: DriverRemoveRequest,
    db: DbSession,
    admin: Annotated[User, Depends(require_admin)],
) -> MutationResponse:
    if not verify_password(request.admin_password, admin.password_salt, admin.password_hash):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Admin password is incorrect.")

    driver = db.scalar(select(User).where(User.id == driver_id, User.role == "driver"))
    if driver is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Driver not found.")

    db.execute(delete(AuthSession).where(AuthSession.user_id == driver.id))
    removed_driver_id = driver.id
    db.delete(driver)
    db.commit()
    manager.broadcast_driver(removed_driver_id, {"type": "session_revoked", "reason": "Driver account removed."})
    broadcast_admin_fleet_changed(db)
    return MutationResponse(success=True, message="Driver account removed.")


# ── Bookings ─────────────────────────────────────────────────────────────────

def get_booking_with_relations(
    db: Session,
    *,
    booking_id: int | None = None,
    public_code: str | None = None,
) -> Booking | None:
    query = select(Booking).options(
        selectinload(Booking.bus),
        selectinload(Booking.pickup_stop),
        selectinload(Booking.destination_stop),
        selectinload(Booking.seats).selectinload(BookingSeat.seat),
    )
    if booking_id is not None:
        query = query.where(Booking.id == booking_id)
    elif public_code is not None:
        query = query.where(Booking.public_code == public_code)
    else:
        raise ValueError("booking_id or public_code is required")
    return db.scalar(query)


def build_booking_response(booking: Booking) -> BookingResponse:
    seats = [BookingSeatResponse(id=bs.seat.id, label=bs.seat.label) for bs in booking.seats]
    distance_km = None
    if booking.pickup_stop is not None and booking.destination_stop is not None:
        distance_km = round(
            haversine_distance_km(
                booking.pickup_stop.lat,
                booking.pickup_stop.lng,
                booking.destination_stop.lat,
                booking.destination_stop.lng,
            ),
            1,
        )
    return BookingResponse(
        id=booking.id,
        public_code=booking.public_code,
        status=booking.status,  # type: ignore[arg-type]
        bus_id=booking.bus_id,
        bus_name=booking.bus.name,
        route_name=booking.bus.route_name,
        pickup_stop_name=booking.pickup_stop.name if booking.pickup_stop else None,
        destination_stop_name=booking.destination_stop.name if booking.destination_stop else None,
        distance_km=distance_km,
        passenger_name=booking.passenger_name,
        payment_method=booking.payment_method,
        fare_total=booking.fare_total,
        seats=seats,
        created_at=booking.created_at,
        updated_at=booking.updated_at,
    )


def create_notification(
    db: Session,
    *,
    user_id: int,
    kind: str,
    title: str,
    body: str,
    booking_id: int | None = None,
) -> NotificationRecord:
    record = NotificationRecord(user_id=user_id, booking_id=booking_id, kind=kind, title=title, body=body)
    db.add(record)
    db.flush()
    return record


@app.post("/api/public/bookings", response_model=BookingResponse)
def create_booking(
    request: BookingCreateRequest,
    db: DbSession,
    authorization: Annotated[str | None, Header()] = None,
) -> BookingResponse:
    bus = get_bus_with_relations(db, request.bus_id)
    if bus is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Bus not found.")

    stops_sorted = sorted(bus.stops, key=lambda s: s.order_index)
    pickup_stop = next((s for s in stops_sorted if s.id == request.pickup_stop_id), None)
    destination_stop = next((s for s in stops_sorted if s.id == request.destination_stop_id), None)
    if pickup_stop is None or destination_stop is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid pickup or destination stop.")
    if pickup_stop.order_index >= destination_stop.order_index:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Destination must be further along the route than the pickup stop.",
        )

    requested_ids = set(request.seat_ids)
    seats = [s for s in bus.seats if s.id in requested_ids]
    if len(seats) != len(requested_ids):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="One or more seats not found on this bus.")
    already_booked = [s.label for s in seats if s.is_booked]
    if already_booked:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Seat(s) {', '.join(already_booked)} are already booked. Please pick different seats.",
        )

    cumulative = cumulative_fares([(s.id, s.fare) for s in stops_sorted])
    fare_per_seat = fare_between_stops(cumulative[pickup_stop.id], cumulative[destination_stop.id])
    fare_total = fare_per_seat * len(seats)

    public_code = generate_booking_code()
    while db.scalar(select(Booking).where(Booking.public_code == public_code)) is not None:
        public_code = generate_booking_code()

    passenger_session = _session_for_token(db, authorization)
    passenger = None
    if passenger_session is not None and passenger_session.expires_at > datetime.utcnow():
        passenger = passenger_session.passenger

    booking = Booking(
        public_code=public_code,
        bus_id=bus.id,
        passenger_id=passenger.id if passenger is not None else None,
        pickup_stop_id=pickup_stop.id,
        destination_stop_id=destination_stop.id,
        passenger_name=request.passenger_name or "Passenger",
        payment_method=request.payment_method,
        fare_total=fare_total,
        status="pending",
    )
    db.add(booking)
    db.flush()

    for seat in seats:
        seat.is_booked = True
        db.add(seat)
        db.add(BookingSeat(booking_id=booking.id, seat_id=seat.id))

    assigned_driver = next((d for d in bus.drivers if d.role == "driver"), None)
    if assigned_driver is not None:
        create_notification(
            db,
            user_id=assigned_driver.id,
            kind="incoming_booking",
            title="New ride request",
            body=(
                f"{booking.passenger_name} booked {len(seats)} seat(s) from "
                f"{pickup_stop.name} to {destination_stop.name}."
            ),
            booking_id=booking.id,
        )

    db.commit()

    saved_booking = get_booking_with_relations(db, booking_id=booking.id)
    response = build_booking_response(saved_booking)

    broadcast_bus_changed(db, bus.id)
    if assigned_driver is not None:
        manager.broadcast_driver(
            assigned_driver.id,
            {"type": "incoming_booking", "booking": response.model_dump(mode="json")},
        )
    return response


@app.get("/api/public/bookings/{public_code}", response_model=BookingResponse)
def get_booking(public_code: str, db: DbSession) -> BookingResponse:
    booking = get_booking_with_relations(db, public_code=public_code)
    if booking is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Booking not found.")
    return build_booking_response(booking)


@app.get("/api/passenger/bookings", response_model=list[BookingResponse])
def list_passenger_bookings(
    db: DbSession,
    passenger: Annotated[PassengerAccount, Depends(require_passenger)],
) -> list[BookingResponse]:
    bookings = db.scalars(
        select(Booking)
        .options(
            selectinload(Booking.bus),
            selectinload(Booking.pickup_stop),
            selectinload(Booking.destination_stop),
            selectinload(Booking.seats).selectinload(BookingSeat.seat),
        )
        .where(Booking.passenger_id == passenger.id)
        .order_by(Booking.created_at.desc())
    ).all()
    return [build_booking_response(booking) for booking in bookings]


@app.get("/api/driver/bookings/pending", response_model=list[BookingResponse])
def list_pending_bookings(
    db: DbSession,
    driver: Annotated[User, Depends(require_driver)],
) -> list[BookingResponse]:
    if driver.assigned_bus_id is None:
        return []
    bookings = db.scalars(
        select(Booking)
        .options(
            selectinload(Booking.bus),
            selectinload(Booking.pickup_stop),
            selectinload(Booking.destination_stop),
            selectinload(Booking.seats).selectinload(BookingSeat.seat),
        )
        .where(Booking.bus_id == driver.assigned_bus_id, Booking.status == "pending")
        .order_by(Booking.created_at)
    ).all()
    return [build_booking_response(b) for b in bookings]


@app.post("/api/driver/bookings/{booking_id}/respond", response_model=BookingResponse)
def respond_to_booking(
    booking_id: int,
    request: BookingRespondRequest,
    db: DbSession,
    driver: Annotated[User, Depends(require_driver)],
) -> BookingResponse:
    booking = get_booking_with_relations(db, booking_id=booking_id)
    if booking is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Booking not found.")
    if booking.bus_id != driver.assigned_bus_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="This booking isn't on your bus.")
    if booking.status != "pending":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="This booking was already handled.")

    if request.accept:
        booking.status = "confirmed"
    else:
        booking.status = "rejected"
        for booking_seat in booking.seats:
            booking_seat.seat.is_booked = False
            db.add(booking_seat.seat)

    db.add(booking)
    db.commit()

    saved_booking = get_booking_with_relations(db, booking_id=booking.id)
    response = build_booking_response(saved_booking)

    manager.broadcast_booking(
        saved_booking.public_code,
        {"type": "booking_updated", "booking": response.model_dump(mode="json")},
    )
    broadcast_bus_changed(db, saved_booking.bus_id)
    return response


# ── Notifications ────────────────────────────────────────────────────────────

@app.get("/api/notifications", response_model=NotificationListResponse)
def list_notifications(
    db: DbSession,
    user: Annotated[User, Depends(require_authenticated_user)],
) -> NotificationListResponse:
    records = db.scalars(
        select(NotificationRecord)
        .where(NotificationRecord.user_id == user.id)
        .order_by(NotificationRecord.created_at.desc())
        .limit(50)
    ).all()
    return NotificationListResponse(
        notifications=[
            NotificationResponse.model_validate(record, from_attributes=True) for record in records
        ]
    )


@app.post("/api/notifications/{notification_id}/read", response_model=MutationResponse)
def mark_notification_read(
    notification_id: int,
    db: DbSession,
    user: Annotated[User, Depends(require_authenticated_user)],
) -> MutationResponse:
    record = db.scalar(
        select(NotificationRecord).where(
            NotificationRecord.id == notification_id,
            NotificationRecord.user_id == user.id,
        )
    )
    if record is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Notification not found.")
    record.read_at = datetime.utcnow()
    db.add(record)
    db.commit()
    return MutationResponse(success=True, message="Notification marked as read.")


# ── WebSockets (real-time push, replaces polling) ───────────────────────────

async def _authenticate_ws_token(db: Session, token: str | None) -> User | PassengerAccount | None:
    if not token:
        return None
    session = db.scalar(
        select(AuthSession)
        .options(joinedload(AuthSession.user), joinedload(AuthSession.passenger))
        .where(AuthSession.token_hash == hash_session_token(token))
    )
    if session is None or session.expires_at <= datetime.utcnow():
        return None
    return session.user or session.passenger


@app.websocket("/ws/public")
async def ws_public(websocket: WebSocket) -> None:
    """Anyone can connect — pushes bus location/seat/status changes to
    every passenger screen instantly instead of waiting for the next poll."""
    await websocket.accept()
    manager.add_public(websocket)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        pass
    finally:
        manager.remove_public(websocket)


@app.websocket("/ws/admin")
async def ws_admin(websocket: WebSocket, token: str | None = Query(default=None)) -> None:
    db = SessionLocal()
    try:
        user = await _authenticate_ws_token(db, token)
    finally:
        db.close()
    if not isinstance(user, User) or user.role != "admin":
        await websocket.close(code=4401)
        return

    await websocket.accept()
    manager.add_admin(websocket)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        pass
    finally:
        manager.remove_admin(websocket)


@app.websocket("/ws/driver")
async def ws_driver(websocket: WebSocket, token: str | None = Query(default=None)) -> None:
    db = SessionLocal()
    try:
        user = await _authenticate_ws_token(db, token)
    finally:
        db.close()
    if not isinstance(user, User) or user.role != "driver":
        await websocket.close(code=4401)
        return

    await websocket.accept()
    manager.add_driver(user.id, websocket)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        pass
    finally:
        manager.remove_driver(user.id, websocket)


@app.websocket("/ws/booking/{public_code}")
async def ws_booking(websocket: WebSocket, public_code: str) -> None:
    """Passengers have no account, so their booking status channel is keyed
    by the booking's public_code instead of a user/session."""
    await websocket.accept()
    manager.add_booking(public_code, websocket)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        pass
    finally:
        manager.remove_booking(public_code, websocket)
