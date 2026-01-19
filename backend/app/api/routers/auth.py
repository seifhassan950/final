from __future__ import annotations
import datetime as dt
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import select
from app.api.deps import get_db, get_current_user
from app.api.schemas.auth import (
    SignupIn,
    LoginIn,
    TokenOut,
    RefreshIn,
    EmailIn,
    VerifyCodeIn,
    VerificationOut,
    PasswordResetVerifyOut,
    PasswordResetIn,
    ChangePasswordIn,
)
from app.core.errors import conflict, unauthorized, bad_request, not_found
from app.core.security import (
    hash_password, verify_password, create_access_token, create_refresh_token,
    hash_refresh_token, refresh_expiry_utc
)
from app.db.models.user import User, UserProfile, RefreshToken, VerificationCode
from app.core.config import settings
import secrets

router = APIRouter()

def _generate_code() -> str:
    return f"{secrets.randbelow(10000):04d}"

def _verification_expiry() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc) + dt.timedelta(minutes=settings.verification_code_expires_min)

def _reset_expiry() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc) + dt.timedelta(minutes=settings.password_reset_expires_min)

def _create_verification(db: Session, user: User, purpose: str) -> tuple[str, VerificationCode]:
    code = _generate_code()
    db.query(VerificationCode).filter(
        VerificationCode.user_id == user.id,
        VerificationCode.purpose == purpose,
        VerificationCode.verified_at.is_(None),
    ).delete()
    vc = VerificationCode(
        user_id=user.id,
        email=user.email,
        purpose=purpose,
        code_hash=hash_refresh_token(code),
        expires_at=_verification_expiry() if purpose == "email_verification" else _reset_expiry(),
    )
    db.add(vc)
    db.commit()
    db.refresh(vc)
    return code, vc

@router.post("/signup", response_model=TokenOut)
def signup(payload: SignupIn, db: Session = Depends(get_db)):
    exists = db.execute(select(User).where(User.email == payload.email)).scalar_one_or_none()
    if exists:
        conflict("Email already registered")
    username_exists = db.execute(
        select(UserProfile).where(UserProfile.username == payload.username)
    ).scalar_one_or_none()
    if username_exists:
        conflict("Username already taken")
    user = User(email=payload.email, password_hash=hash_password(payload.password), role="user", is_active=True)
    user.profile = UserProfile(username=payload.username, bio=None, avatar_url=None, links=None)
    db.add(user); db.flush()
    rt = create_refresh_token()
    db.add(RefreshToken(user_id=user.id, token_hash=hash_refresh_token(rt), expires_at=refresh_expiry_utc()))
    db.commit()
    return TokenOut(access_token=create_access_token(str(user.id), user.role), refresh_token=rt)

@router.post("/login", response_model=TokenOut)
def login(payload: LoginIn, db: Session = Depends(get_db)):
    user = db.execute(select(User).where(User.email == payload.email)).scalar_one_or_none()
    if not user or not verify_password(payload.password, user.password_hash):
        unauthorized("Invalid email or password")
    if not user.is_active:
        unauthorized("User inactive")
    rt = create_refresh_token()
    db.add(RefreshToken(user_id=user.id, token_hash=hash_refresh_token(rt), expires_at=refresh_expiry_utc()))
    db.commit()
    return TokenOut(access_token=create_access_token(str(user.id), user.role), refresh_token=rt)

@router.post("/refresh", response_model=TokenOut)
def refresh(payload: RefreshIn, db: Session = Depends(get_db)):
    token_hash = hash_refresh_token(payload.refresh_token)
    rt = db.execute(select(RefreshToken).where(RefreshToken.token_hash == token_hash)).scalar_one_or_none()
    if not rt or rt.revoked_at is not None:
        unauthorized("Invalid refresh token")
    if rt.expires_at <= dt.datetime.now(dt.timezone.utc):
        unauthorized("Refresh token expired")
    user = db.get(User, rt.user_id)
    if not user or not user.is_active:
        unauthorized("User inactive")
    # rotate token
    rt.revoked_at = dt.datetime.now(dt.timezone.utc)
    new_rt = create_refresh_token()
    db.add(RefreshToken(user_id=user.id, token_hash=hash_refresh_token(new_rt), expires_at=refresh_expiry_utc()))
    db.commit()
    return TokenOut(access_token=create_access_token(str(user.id), user.role), refresh_token=new_rt)

@router.post("/logout")
def logout(payload: RefreshIn, db: Session = Depends(get_db)):
    token_hash = hash_refresh_token(payload.refresh_token)
    rt = db.execute(select(RefreshToken).where(RefreshToken.token_hash == token_hash)).scalar_one_or_none()
    if not rt:
        bad_request("Unknown refresh token")
    rt.revoked_at = dt.datetime.now(dt.timezone.utc)
    db.commit()
    return {"detail": "ok"}

@router.post("/verify/request", response_model=VerificationOut)
def request_verification(payload: EmailIn, db: Session = Depends(get_db)):
    user = db.execute(select(User).where(User.email == payload.email)).scalar_one_or_none()
    if not user:
        return VerificationOut(detail="ok")
    code, _ = _create_verification(db, user, "email_verification")
    if settings.env == "dev":
        return VerificationOut(detail="ok", dev_code=code)
    return VerificationOut(detail="ok")

@router.post("/verify/confirm", response_model=VerificationOut)
def confirm_verification(payload: VerifyCodeIn, db: Session = Depends(get_db)):
    user = db.execute(select(User).where(User.email == payload.email)).scalar_one_or_none()
    if not user:
        not_found("Account not found")
    code_hash = hash_refresh_token(payload.code)
    vc = db.execute(
        select(VerificationCode).where(
            VerificationCode.user_id == user.id,
            VerificationCode.purpose == "email_verification",
            VerificationCode.code_hash == code_hash,
            VerificationCode.verified_at.is_(None),
        )
    ).scalar_one_or_none()
    if not vc:
        bad_request("Invalid code")
    if vc.expires_at <= dt.datetime.now(dt.timezone.utc):
        bad_request("Code expired")
    vc.verified_at = dt.datetime.now(dt.timezone.utc)
    db.commit()
    return VerificationOut(detail="ok")

@router.post("/password/forgot", response_model=VerificationOut)
def password_forgot(payload: EmailIn, db: Session = Depends(get_db)):
    user = db.execute(select(User).where(User.email == payload.email)).scalar_one_or_none()
    if not user:
        return VerificationOut(detail="ok")
    code, _ = _create_verification(db, user, "password_reset")
    if settings.env == "dev":
        return VerificationOut(detail="ok", dev_code=code)
    return VerificationOut(detail="ok")

@router.post("/password/verify", response_model=PasswordResetVerifyOut)
def password_verify(payload: VerifyCodeIn, db: Session = Depends(get_db)):
    user = db.execute(select(User).where(User.email == payload.email)).scalar_one_or_none()
    if not user:
        not_found("Account not found")
    code_hash = hash_refresh_token(payload.code)
    vc = db.execute(
        select(VerificationCode).where(
            VerificationCode.user_id == user.id,
            VerificationCode.purpose == "password_reset",
            VerificationCode.code_hash == code_hash,
            VerificationCode.verified_at.is_(None),
        )
    ).scalar_one_or_none()
    if not vc:
        bad_request("Invalid code")
    if vc.expires_at <= dt.datetime.now(dt.timezone.utc):
        bad_request("Code expired")
    reset_token = create_refresh_token()
    vc.token_hash = hash_refresh_token(reset_token)
    vc.verified_at = dt.datetime.now(dt.timezone.utc)
    db.commit()
    return PasswordResetVerifyOut(reset_token=reset_token)

@router.post("/password/reset")
def password_reset(payload: PasswordResetIn, db: Session = Depends(get_db)):
    token_hash = hash_refresh_token(payload.reset_token)
    vc = db.execute(
        select(VerificationCode).where(
            VerificationCode.purpose == "password_reset",
            VerificationCode.token_hash == token_hash,
        )
    ).scalar_one_or_none()
    if not vc:
        bad_request("Invalid reset token")
    if vc.expires_at <= dt.datetime.now(dt.timezone.utc):
        bad_request("Reset token expired")
    user = db.get(User, vc.user_id)
    if not user:
        not_found("Account not found")
    user.password_hash = hash_password(payload.new_password)
    # revoke refresh tokens
    db.query(RefreshToken).filter(RefreshToken.user_id == user.id).delete()
    db.delete(vc)
    db.commit()
    return {"detail": "ok"}

@router.post("/password/change")
def password_change(payload: ChangePasswordIn, db: Session = Depends(get_db), user = Depends(get_current_user)):
    user.password_hash = hash_password(payload.new_password)
    db.query(RefreshToken).filter(RefreshToken.user_id == user.id).delete()
    db.commit()
    return {"detail": "ok"}
