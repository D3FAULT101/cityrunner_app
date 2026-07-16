from __future__ import annotations

import json
from datetime import datetime
from math import atan2, cos, radians, sin, sqrt

from .models import Coordinate


DEFAULT_ROUTE_NAME = "Gangtok → Ranipool"

ROUTE_STOPS = [
    {"name": "Gangtok", "lat": 27.3389, "lng": 88.6065, "fare": 0},
    {"name": "Tadong", "lat": 27.3086, "lng": 88.5989, "fare": 15},
    {"name": "6th Mile", "lat": 27.3008, "lng": 88.5934, "fare": 10},
    {"name": "Boomtar", "lat": 27.2916, "lng": 88.5881, "fare": 12},
    {"name": "Singtam Turn", "lat": 27.2814, "lng": 88.5814, "fare": 10},
    {"name": "Ranipool", "lat": 27.2749, "lng": 88.5792, "fare": 13},
]

FULL_ROUTE_FARE = 60

ROUTE_POLYLINE = [
    Coordinate(lat=27.3389, lng=88.6065),
    Coordinate(lat=27.3349, lng=88.6056),
    Coordinate(lat=27.3296, lng=88.6042),
    Coordinate(lat=27.3238, lng=88.6024),
    Coordinate(lat=27.3177, lng=88.6006),
    Coordinate(lat=27.3123, lng=88.5994),
    Coordinate(lat=27.3086, lng=88.5989),
    Coordinate(lat=27.3054, lng=88.5967),
    Coordinate(lat=27.3008, lng=88.5934),
    Coordinate(lat=27.2965, lng=88.5908),
    Coordinate(lat=27.2916, lng=88.5881),
    Coordinate(lat=27.2869, lng=88.5848),
    Coordinate(lat=27.2814, lng=88.5814),
    Coordinate(lat=27.2781, lng=88.5801),
    Coordinate(lat=27.2749, lng=88.5792),
]

SEAT_LAYOUT_TEMPLATE = [
    ("S1", "S1", 0, "front"),
    ("S2", "S2", 1, "left"),
    ("S3", "S3", 1, "right"),
    ("S4", "S4", 2, "left"),
    ("S5", "S5", 2, "right"),
    ("S6", "S6", 3, "left"),
    ("S7", "S7", 3, "right"),
    ("S8", "S8", 4, "left"),
    ("S9", "S9", 4, "right"),
    ("S10", "S10", 5, "left"),
    ("S11", "S11", 5, "right"),
    ("S12", "S12", 6, "left"),
    ("S13", "S13", 6, "right"),
    ("S14", "S14", 7, "rear-1"),
    ("S15", "S15", 7, "rear-2"),
    ("S16", "S16", 7, "rear-3"),
    ("S17", "S17", 7, "rear-4"),
]


def default_route_polyline_json() -> str:
    return json.dumps([point.model_dump() for point in ROUTE_POLYLINE])


def parse_route_polyline(route_polyline_json: str) -> list[Coordinate]:
    raw_points = json.loads(route_polyline_json)
    return [Coordinate(**point) for point in raw_points]


def haversine_distance_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    earth_radius = 6371.0
    d_lat = radians(lat2 - lat1)
    d_lng = radians(lng2 - lng1)
    a = sin(d_lat / 2) ** 2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(d_lng / 2) ** 2
    c = 2 * atan2(sqrt(a), sqrt(1 - a))
    return earth_radius * c


def estimate_eta_minutes(current_lat: float, current_lng: float, destination_lat: float, destination_lng: float) -> int:
    distance = haversine_distance_km(current_lat, current_lng, destination_lat, destination_lng)
    average_speed_kmh = 22
    if distance <= 0.2:
        return 1
    return max(1, round((distance / average_speed_kmh) * 60))


def get_current_stop_index(current_lat: float, current_lng: float, stops: list[tuple[float, float]]) -> int:
    nearest_index = 0
    nearest_distance = float("inf")
    for index, (stop_lat, stop_lng) in enumerate(stops):
        distance = haversine_distance_km(current_lat, current_lng, stop_lat, stop_lng)
        if distance < nearest_distance:
            nearest_distance = distance
            nearest_index = index
    return nearest_index


def location_is_fresh(location_updated_at: datetime | None, threshold_minutes: int = 3) -> bool:
    if location_updated_at is None:
        return False
    now = datetime.utcnow()
    return (now - location_updated_at).total_seconds() <= threshold_minutes * 60


def cumulative_fares(stops_by_order: list[tuple[int, int]]) -> dict[int, int]:
    """`stops_by_order` is [(stop_id, leg_fare), ...] sorted by order_index.
    Stop fares in ROUTE_STOPS are per-leg, so the fare to reach a given stop
    from the route's origin is the running total up to and including it."""
    total = 0
    cumulative: dict[int, int] = {}
    for stop_id, leg_fare in stops_by_order:
        total += leg_fare
        cumulative[stop_id] = total
    return cumulative


def fare_between_stops(pickup_cumulative_fare: int, destination_cumulative_fare: int) -> int:
    return max(0, destination_cumulative_fare - pickup_cumulative_fare)
