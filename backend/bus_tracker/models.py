from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


Role = Literal["admin", "driver"]


class Coordinate(BaseModel):
    lat: float
    lng: float


class StopResponse(BaseModel):
    id: int
    name: str
    coordinate: Coordinate
    fare: int
    order_index: int


class SeatResponse(BaseModel):
    id: int
    seat_code: str
    label: str
    row_number: int
    column_name: str
    is_booked: bool


class DriverSummaryResponse(BaseModel):
    id: int
    username: str
    display_name: str
    is_active: bool
    must_change_password: bool
    assigned_bus_id: int | None
    assigned_bus_name: str | None = None


class BusResponse(BaseModel):
    id: int
    name: str
    registration_number: str
    route_name: str
    seat_capacity: int
    is_active: bool
    current_stop_index: int | None
    eta_minutes: int | None
    available_seats: int
    has_live_location: bool
    location_updated_at: datetime | None
    position: Coordinate | None
    route: list[Coordinate]
    stops: list[StopResponse]
    seats: list[SeatResponse]
    assigned_driver: DriverSummaryResponse | None = None


class PublicOverviewResponse(BaseModel):
    buses: list[BusResponse]


class AdminOverviewResponse(BaseModel):
    buses: list[BusResponse]
    drivers: list[DriverSummaryResponse]


class UserSessionResponse(BaseModel):
    id: int
    username: str
    display_name: str
    role: Role
    assigned_bus_id: int | None
    must_change_password: bool


class DriverDashboardResponse(BaseModel):
    user: UserSessionResponse
    bus: BusResponse | None


class LoginRequest(BaseModel):
    username: str = Field(min_length=3, max_length=64)
    password: str = Field(min_length=8, max_length=128)


class LoginResponse(BaseModel):
    success: bool
    message: str
    token: str | None = None
    user: UserSessionResponse | None = None


class OtpRequest(BaseModel):
    phone_number: str = Field(min_length=6, max_length=32)


class OtpVerifyRequest(OtpRequest):
    code: str = Field(min_length=6, max_length=6)


class PassengerAccountResponse(BaseModel):
    id: int
    phone_number: str
    display_name: str | None


class OtpRequestResponse(BaseModel):
    success: bool
    message: str
    dev_code: str | None = None


class PassengerLoginResponse(BaseModel):
    success: bool
    token: str
    passenger: PassengerAccountResponse


FirebaseRole = Literal["passenger", "driver", "admin"]


class FirebaseExchangeRequest(BaseModel):
    id_token: str = Field(min_length=20, max_length=8192)
    role: FirebaseRole


class FirebaseLinkRequest(BaseModel):
    id_token: str = Field(min_length=20, max_length=8192)


class DeviceTokenRequest(BaseModel):
    token: str = Field(min_length=20, max_length=512)
    platform: str | None = Field(default=None, max_length=16)


class ChangePasswordRequest(BaseModel):
    current_password: str = Field(min_length=8, max_length=128)
    new_password: str = Field(min_length=8, max_length=128)


class DriverLocationUpdateRequest(BaseModel):
    lat: float
    lng: float
    accuracy_meters: float | None = None


class BusCreateRequest(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    registration_number: str = Field(min_length=2, max_length=32)
    route_name: str = Field(default="Gangtok → Ranipool", min_length=3, max_length=120)


class DriverCreateRequest(BaseModel):
    username: str = Field(min_length=3, max_length=64)
    display_name: str = Field(min_length=2, max_length=120)
    password: str = Field(min_length=8, max_length=128)
    assigned_bus_id: int | None = None


class DriverPasswordResetRequest(BaseModel):
    new_password: str = Field(min_length=8, max_length=128)


class DriverRemoveRequest(BaseModel):
    admin_password: str = Field(min_length=8, max_length=128)


class MutationResponse(BaseModel):
    success: bool
    message: str


BookingStatus = Literal["pending", "confirmed", "rejected", "cancelled", "completed"]


class BookingSeatResponse(BaseModel):
    id: int
    label: str


class BookingResponse(BaseModel):
    id: int
    public_code: str
    status: BookingStatus
    bus_id: int
    bus_name: str
    route_name: str
    pickup_stop_name: str | None
    destination_stop_name: str | None
    distance_km: float | None = None
    passenger_name: str
    payment_method: str
    fare_total: int
    seats: list[BookingSeatResponse]
    created_at: datetime
    updated_at: datetime


class BookingCreateRequest(BaseModel):
    bus_id: int
    seat_ids: list[int] = Field(min_length=1, max_length=8)
    pickup_stop_id: int
    destination_stop_id: int
    payment_method: str = Field(min_length=2, max_length=24)
    passenger_name: str = Field(default="Passenger", max_length=120)


class BookingRespondRequest(BaseModel):
    accept: bool


class NotificationResponse(BaseModel):
    id: int
    kind: str
    title: str
    body: str
    booking_id: int | None
    created_at: datetime
    read_at: datetime | None


class NotificationListResponse(BaseModel):
    notifications: list[NotificationResponse]
