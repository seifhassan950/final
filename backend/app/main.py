from __future__ import annotations

import time
import uuid
import re

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import ORJSONResponse
from starlette.middleware.base import BaseHTTPMiddleware

from app.core.config import settings
from app.core.logging import configure_logging, get_logger
from app.core.rate_limit import rate_limit_middleware
from app.api.router import api_router

configure_logging()
log = get_logger(__name__)

class NormalizePathMiddleware:
    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] in {"http", "websocket"}:
            path = scope.get("path", "")
            if "//" in path:
                normalized = re.sub(r"/+", "/", path)
                scope = dict(scope)
                scope["path"] = normalized
                if "raw_path" in scope:
                    scope["raw_path"] = normalized.encode()
        await self.app(scope, receive, send)

class RequestIDMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        request_id = request.headers.get("x-request-id") or str(uuid.uuid4())
        request.state.request_id = request_id
        start = time.time()
        response = await call_next(request)
        response.headers["x-request-id"] = request_id
        duration_ms = int((time.time() - start) * 1000)
        log.info(
            "request",
            extra={
                "request_id": request_id,
                "method": request.method,
                "path": request.url.path,
                "status_code": response.status_code,
                "duration_ms": duration_ms,
            },
        )
        return response

app = FastAPI(
    title="R2V Studio Backend",
    version="0.1.0",
    default_response_class=ORJSONResponse,
)

app.add_middleware(NormalizePathMiddleware)
app.add_middleware(RequestIDMiddleware)
app.add_middleware(
    CORSMiddleware,
    allow_origins=[o.strip() for o in settings.allowed_origins.split(",") if o.strip()],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    allow_origin_regex=settings.allowed_origin_regex,
)


app.middleware("http")(rate_limit_middleware)
app.include_router(api_router)

@app.get("/health")
async def health():
    return {"ok": True, "env": settings.env}
