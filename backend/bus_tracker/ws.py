from __future__ import annotations

import asyncio
import logging
from typing import Any

from fastapi import WebSocket

logger = logging.getLogger("bus_tracker.ws")


class ConnectionManager:
    """Tracks active WebSocket clients and broadcasts JSON payloads to them.

    Route handlers in `main.py` are regular sync `def`s (FastAPI runs them in
    a worker thread), so they can't `await` a broadcast directly. Instead,
    `broadcast_*` schedules the send coroutine onto the event loop that was
    captured at startup, via `asyncio.run_coroutine_threadsafe`. WebSocket
    handlers themselves are `async def`s and can call `await` directly if
    needed, but use the same scheduling path for consistency.
    """

    def __init__(self) -> None:
        self._loop: asyncio.AbstractEventLoop | None = None
        self.public: set[WebSocket] = set()
        self.admin: set[WebSocket] = set()
        self.driver: dict[int, set[WebSocket]] = {}
        self.booking: dict[str, set[WebSocket]] = {}

    def bind_loop(self, loop: asyncio.AbstractEventLoop) -> None:
        self._loop = loop

    # ── connection lifecycle ────────────────────────────────────────────────

    def add_public(self, ws: WebSocket) -> None:
        self.public.add(ws)

    def remove_public(self, ws: WebSocket) -> None:
        self.public.discard(ws)

    def add_admin(self, ws: WebSocket) -> None:
        self.admin.add(ws)

    def remove_admin(self, ws: WebSocket) -> None:
        self.admin.discard(ws)

    def add_driver(self, driver_id: int, ws: WebSocket) -> None:
        self.driver.setdefault(driver_id, set()).add(ws)

    def remove_driver(self, driver_id: int, ws: WebSocket) -> None:
        sockets = self.driver.get(driver_id)
        if not sockets:
            return
        sockets.discard(ws)
        if not sockets:
            self.driver.pop(driver_id, None)

    def add_booking(self, code: str, ws: WebSocket) -> None:
        self.booking.setdefault(code, set()).add(ws)

    def remove_booking(self, code: str, ws: WebSocket) -> None:
        sockets = self.booking.get(code)
        if not sockets:
            return
        sockets.discard(ws)
        if not sockets:
            self.booking.pop(code, None)

    # ── broadcasting (safe to call from sync request handlers) ─────────────

    def broadcast_public(self, payload: dict[str, Any]) -> None:
        self._schedule(self._send_all(self.public, payload))

    def broadcast_admin(self, payload: dict[str, Any]) -> None:
        self._schedule(self._send_all(self.admin, payload))

    def broadcast_driver(self, driver_id: int, payload: dict[str, Any]) -> None:
        sockets = self.driver.get(driver_id)
        if sockets:
            self._schedule(self._send_all(sockets, payload))

    def broadcast_booking(self, code: str, payload: dict[str, Any]) -> None:
        sockets = self.booking.get(code)
        if sockets:
            self._schedule(self._send_all(sockets, payload))

    def _schedule(self, coro: "asyncio.coroutines.Coroutine[Any, Any, None]") -> None:
        if self._loop is None:
            logger.warning("WebSocket broadcast dropped: event loop not bound yet.")
            return
        asyncio.run_coroutine_threadsafe(coro, self._loop)

    async def _send_all(self, sockets: set[WebSocket], payload: dict[str, Any]) -> None:
        dead: list[WebSocket] = []
        for ws in list(sockets):
            try:
                await ws.send_json(payload)
            except Exception:  # noqa: BLE001 - connection may have dropped
                dead.append(ws)
        for ws in dead:
            sockets.discard(ws)


manager = ConnectionManager()
