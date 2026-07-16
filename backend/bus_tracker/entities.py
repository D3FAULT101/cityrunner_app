from __future__ import annotations

from datetime import datetime

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .db import Base


def utc_now() -> datetime:
    return datetime.utcnow()


class Bus(Base):
    __tablename__ = "buses"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    registration_number: Mapped[str] = mapped_column(String(32), nullable=False, unique=True)
    route_name: Mapped[str] = mapped_column(String(120), nullable=False)
    route_polyline_json: Mapped[str] = mapped_column(Text, nullable=False)
    seat_capacity: Mapped[int] = mapped_column(Integer, nullable=False, default=17)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    last_lat: Mapped[float | None] = mapped_column(Float, nullable=True)
    last_lng: Mapped[float | None] = mapped_column(Float, nullable=True)
    last_accuracy_meters: Mapped[float | None] = mapped_column(Float, nullable=True)
    location_updated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, onupdate=utc_now, nullable=False)

    stops: Mapped[list["BusStop"]] = relationship(
        back_populates="bus",
        cascade="all, delete-orphan",
        order_by="BusStop.order_index",
    )
    seats: Mapped[list["Seat"]] = relationship(
        back_populates="bus",
        cascade="all, delete-orphan",
        order_by="Seat.id",
    )
    drivers: Mapped[list["User"]] = relationship(back_populates="assigned_bus")


class BusStop(Base):
    __tablename__ = "bus_stops"
    __table_args__ = (UniqueConstraint("bus_id", "order_index", name="uq_bus_stop_order"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    bus_id: Mapped[int] = mapped_column(ForeignKey("buses.id", ondelete="CASCADE"), nullable=False)
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    lat: Mapped[float] = mapped_column(Float, nullable=False)
    lng: Mapped[float] = mapped_column(Float, nullable=False)
    fare: Mapped[int] = mapped_column(Integer, nullable=False)
    order_index: Mapped[int] = mapped_column(Integer, nullable=False)

    bus: Mapped[Bus] = relationship(back_populates="stops")


class Seat(Base):
    __tablename__ = "seats"
    __table_args__ = (UniqueConstraint("bus_id", "seat_code", name="uq_bus_seat_code"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    bus_id: Mapped[int] = mapped_column(ForeignKey("buses.id", ondelete="CASCADE"), nullable=False)
    seat_code: Mapped[str] = mapped_column(String(16), nullable=False)
    label: Mapped[str] = mapped_column(String(16), nullable=False)
    row_number: Mapped[int] = mapped_column(Integer, nullable=False)
    column_name: Mapped[str] = mapped_column(String(16), nullable=False)
    is_booked: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)

    bus: Mapped[Bus] = relationship(back_populates="seats")


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    username: Mapped[str] = mapped_column(String(64), unique=True, nullable=False, index=True)
    firebase_uid: Mapped[str | None] = mapped_column(String(128), unique=True, nullable=True, index=True)
    display_name: Mapped[str] = mapped_column(String(120), nullable=False)
    role: Mapped[str] = mapped_column(String(16), nullable=False)
    password_hash: Mapped[str] = mapped_column(String(128), nullable=False)
    password_salt: Mapped[str] = mapped_column(String(64), nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    must_change_password: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    assigned_bus_id: Mapped[int | None] = mapped_column(ForeignKey("buses.id", ondelete="SET NULL"), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, onupdate=utc_now, nullable=False)

    assigned_bus: Mapped[Bus | None] = relationship(back_populates="drivers")
    sessions: Mapped[list["AuthSession"]] = relationship(
        back_populates="user",
        cascade="all, delete-orphan",
        order_by="AuthSession.created_at",
    )


class PassengerAccount(Base):
    __tablename__ = "passenger_accounts"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    phone_number: Mapped[str] = mapped_column(String(32), unique=True, nullable=False, index=True)
    firebase_uid: Mapped[str | None] = mapped_column(String(128), unique=True, nullable=True, index=True)
    display_name: Mapped[str | None] = mapped_column(String(120), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)

    sessions: Mapped[list["AuthSession"]] = relationship(back_populates="passenger", cascade="all, delete-orphan")
    bookings: Mapped[list["Booking"]] = relationship(back_populates="passenger")


class OtpChallenge(Base):
    __tablename__ = "otp_challenges"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    phone_number: Mapped[str] = mapped_column(String(32), nullable=False, index=True)
    code_hash: Mapped[str] = mapped_column(String(128), nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    attempts: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    consumed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)


class AuthSession(Base):
    __tablename__ = "auth_sessions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    token_hash: Mapped[str] = mapped_column(String(128), unique=True, nullable=False, index=True)
    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=True)
    passenger_id: Mapped[int | None] = mapped_column(ForeignKey("passenger_accounts.id", ondelete="CASCADE"), nullable=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)

    user: Mapped[User | None] = relationship(back_populates="sessions")
    passenger: Mapped[PassengerAccount | None] = relationship(back_populates="sessions")


class Booking(Base):
    """A booking can be anonymous, or linked to a passenger account."""

    __tablename__ = "bookings"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    public_code: Mapped[str] = mapped_column(String(16), unique=True, nullable=False, index=True)
    bus_id: Mapped[int] = mapped_column(ForeignKey("buses.id", ondelete="CASCADE"), nullable=False)
    passenger_id: Mapped[int | None] = mapped_column(ForeignKey("passenger_accounts.id", ondelete="SET NULL"), nullable=True, index=True)
    pickup_stop_id: Mapped[int] = mapped_column(ForeignKey("bus_stops.id", ondelete="SET NULL"), nullable=True)
    destination_stop_id: Mapped[int] = mapped_column(ForeignKey("bus_stops.id", ondelete="SET NULL"), nullable=True)
    passenger_name: Mapped[str] = mapped_column(String(120), nullable=False, default="Passenger")
    payment_method: Mapped[str] = mapped_column(String(24), nullable=False)
    fare_total: Mapped[int] = mapped_column(Integer, nullable=False)
    # pending -> just requested, waiting on driver; confirmed/rejected -> driver responded;
    # cancelled -> passenger cancelled; completed -> trip finished.
    status: Mapped[str] = mapped_column(String(16), nullable=False, default="pending")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, onupdate=utc_now, nullable=False)

    bus: Mapped[Bus] = relationship()
    passenger: Mapped[PassengerAccount | None] = relationship(back_populates="bookings")
    pickup_stop: Mapped["BusStop | None"] = relationship(foreign_keys=[pickup_stop_id])
    destination_stop: Mapped["BusStop | None"] = relationship(foreign_keys=[destination_stop_id])
    seats: Mapped[list["BookingSeat"]] = relationship(
        back_populates="booking",
        cascade="all, delete-orphan",
        order_by="BookingSeat.id",
    )


class BookingSeat(Base):
    __tablename__ = "booking_seats"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    booking_id: Mapped[int] = mapped_column(ForeignKey("bookings.id", ondelete="CASCADE"), nullable=False)
    seat_id: Mapped[int] = mapped_column(ForeignKey("seats.id", ondelete="CASCADE"), nullable=False)

    booking: Mapped[Booking] = relationship(back_populates="seats")
    seat: Mapped[Seat] = relationship()


class NotificationRecord(Base):
    """A notification for a driver or admin account. Passenger-facing
    updates (booking confirmed/rejected) are pushed over the booking's
    WebSocket channel instead, since passengers have no account to own a
    notification row."""

    __tablename__ = "notifications"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    booking_id: Mapped[int | None] = mapped_column(ForeignKey("bookings.id", ondelete="SET NULL"), nullable=True)
    kind: Mapped[str] = mapped_column(String(32), nullable=False)
    title: Mapped[str] = mapped_column(String(160), nullable=False)
    body: Mapped[str] = mapped_column(String(280), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)
    read_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class DeviceToken(Base):
    __tablename__ = "device_tokens"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    token: Mapped[str] = mapped_column(String(512), unique=True, nullable=False, index=True)
    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=True, index=True)
    passenger_id: Mapped[int | None] = mapped_column(ForeignKey("passenger_accounts.id", ondelete="CASCADE"), nullable=True, index=True)
    platform: Mapped[str | None] = mapped_column(String(16), nullable=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, onupdate=utc_now, nullable=False)
