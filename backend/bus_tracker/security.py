from __future__ import annotations

import hashlib
import hmac
import secrets
from datetime import datetime, timedelta


PBKDF2_ITERATIONS = 310_000
SESSION_TTL_HOURS = 24


def utc_now() -> datetime:
    return datetime.utcnow()


def generate_password_salt() -> str:
    return secrets.token_hex(16)


def hash_password(password: str, salt: str) -> str:
    derived = hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        salt.encode("utf-8"),
        PBKDF2_ITERATIONS,
    )
    return derived.hex()


def verify_password(password: str, salt: str, expected_hash: str) -> bool:
    candidate = hash_password(password, salt)
    return hmac.compare_digest(candidate, expected_hash)


def create_password_record(password: str) -> tuple[str, str]:
    salt = generate_password_salt()
    return hash_password(password, salt), salt


def create_session_token() -> tuple[str, str, datetime]:
    token = secrets.token_urlsafe(32)
    token_hash = hashlib.sha256(token.encode("utf-8")).hexdigest()
    expires_at = utc_now() + timedelta(hours=SESSION_TTL_HOURS)
    return token, token_hash, expires_at


def hash_session_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def generate_booking_code() -> str:
    # Short, human-shareable code (e.g. "A1B2C3D4") the passenger app keeps
    # locally to poll/subscribe to their booking without needing an account.
    return secrets.token_hex(4).upper()
