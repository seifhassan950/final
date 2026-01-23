from __future__ import annotations
from typing import Generator
from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session
from app.core.errors import unauthorized, forbidden
from app.core.security import decode_token
from app.db.session import SessionLocal
from app.db.models.user import User

bearer = HTTPBearer(auto_error=False)

def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def get_current_user(
    creds: HTTPAuthorizationCredentials | None = Depends(bearer),
    db: Session = Depends(get_db),
) -> User:
    if not creds:
        unauthorized("Missing bearer token")
    try:
        payload = decode_token(creds.credentials)
    except Exception:
        unauthorized("Invalid token")
    if payload.get("type") != "access":
        unauthorized("Invalid token type")
    user_id = payload.get("sub")
    user = db.get(User, user_id)
    if not user or not user.is_active:
        unauthorized("User inactive")
    user._jwt_role = payload.get("role")  # type: ignore[attr-defined]
    return user

def require_admin(user: User = Depends(get_current_user)) -> User:
    role = getattr(user, "_jwt_role", user.role)
    if role != "admin":
        forbidden("Admin only")
    return user
