from __future__ import annotations

import os
from functools import lru_cache
from typing import Any

import firebase_admin
from firebase_admin import auth, credentials, messaging


class FirebaseConfigurationError(RuntimeError):
    pass


@lru_cache(maxsize=1)
def firebase_app() -> firebase_admin.App:
    service_account_path = os.getenv("FIREBASE_SERVICE_ACCOUNT_PATH")
    if not service_account_path:
        raise FirebaseConfigurationError("FIREBASE_SERVICE_ACCOUNT_PATH is not configured.")
    if not os.path.isfile(service_account_path):
        raise FirebaseConfigurationError("Firebase service-account file was not found.")
    try:
        return firebase_admin.get_app()
    except ValueError:
        return firebase_admin.initialize_app(credentials.Certificate(service_account_path))


def verify_id_token(id_token: str) -> dict[str, Any]:
    return dict(auth.verify_id_token(id_token, app=firebase_app(), check_revoked=True))


def send_push(tokens: list[str], *, title: str, body: str, data: dict[str, str]) -> None:
    if not tokens:
        return
    try:
        response = messaging.send_each_for_multicast(
            messaging.MulticastMessage(
                tokens=tokens,
                notification=messaging.Notification(title=title, body=body),
                data=data,
                android=messaging.AndroidConfig(priority="high"),
                apns=messaging.APNSConfig(headers={"apns-priority": "10"}),
            ),
            app=firebase_app(),
        )
        # Invalid tokens are left for an explicit periodic cleanup job.  A push
        # failure must never roll back an already committed booking operation.
        _ = response
    except Exception:
        # FCM delivery is best-effort; the in-app/WebSocket notification path
        # remains authoritative when Firebase is temporarily unavailable.
        return
