from __future__ import annotations
import datetime as dt
from fastapi import APIRouter, Depends, Request
from fastapi.responses import RedirectResponse
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
from app.db.models.oauth_account import OAuthAccount
from app.core.config import settings
import secrets
from jose import jwt
import httpx
from urllib.parse import urlencode, urlparse, urlunparse, parse_qsl

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


def _oauth_provider_config(provider: str) -> dict[str, str]:
    configs = {
        "google": {
            "auth_url": "https://accounts.google.com/o/oauth2/v2/auth",
            "token_url": "https://oauth2.googleapis.com/token",
            "jwks_url": "https://www.googleapis.com/oauth2/v3/certs",
            "issuer": "https://accounts.google.com",
            "scope": "openid email profile",
            "client_id": settings.google_oauth_client_id,
            "client_secret": settings.google_oauth_client_secret,
            "mock": False,
        },
        "apple": {
            "auth_url": "https://appleid.apple.com/auth/authorize",
            "token_url": "https://appleid.apple.com/auth/token",
            "jwks_url": "https://appleid.apple.com/auth/keys",
            "issuer": "https://appleid.apple.com",
            "scope": "name email",
            "client_id": settings.apple_oauth_client_id,
            "client_secret": "",
            "mock": False,
        },
        "microsoft": {
            "auth_url": "https://login.microsoftonline.com/common/oauth2/v2.0/authorize",
            "token_url": "https://login.microsoftonline.com/common/oauth2/v2.0/token",
            "jwks_url": "https://login.microsoftonline.com/common/discovery/v2.0/keys",
            "issuer": "https://login.microsoftonline.com/",
            "scope": "openid email profile",
            "client_id": settings.microsoft_oauth_client_id,
            "client_secret": settings.microsoft_oauth_client_secret,
            "mock": False,
        },
    }

    if provider not in configs:
        bad_request("Unsupported OAuth provider")

    config = configs[provider]
    if provider == "apple":
        configured = (
            settings.apple_oauth_client_id
            and settings.apple_team_id
            and settings.apple_key_id
            and settings.apple_private_key
        )
        if not configured:
            if settings.env == "dev":
                config["mock"] = True
                config["client_id"] = config["client_id"] or "dev-apple-client-id"
            else:
                bad_request("Apple OAuth is not configured")
    else:
        configured = config["client_id"] and config["client_secret"]
        if not configured:
            if settings.env == "dev":
                config["mock"] = True
                config["client_id"] = config["client_id"] or f"dev-{provider}-client-id"
                config["client_secret"] = config["client_secret"] or "dev-client-secret"
            else:
                bad_request(f"{provider.title()} OAuth is not configured")

    return config


def _encode_state(data: dict) -> str:
    payload = {
        **data,
        "exp": int((dt.datetime.now(dt.timezone.utc) + dt.timedelta(minutes=10)).timestamp()),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm="HS256")

def _mock_claims(provider: str) -> dict:
    email = f"{provider}_dev@example.com"
    return {"sub": f"dev-{provider}", "email": email, "preferred_username": email}

def _issue_tokens_for_user(db: Session, user: User) -> TokenOut:
    rt = create_refresh_token()
    db.add(
        RefreshToken(
            user_id=user.id,
            token_hash=hash_refresh_token(rt),
            expires_at=refresh_expiry_utc(),
        )
    )
    db.commit()
    access = create_access_token(str(user.id), user.role)
    return TokenOut(access_token=access, refresh_token=rt)


def _decode_state(state: str) -> dict:
    try:
        return jwt.decode(state, settings.jwt_secret, algorithms=["HS256"])
    except Exception:
        bad_request("Invalid OAuth state")


def _apple_client_secret() -> str:
    now = dt.datetime.now(dt.timezone.utc)
    payload = {
        "iss": settings.apple_team_id,
        "iat": int(now.timestamp()),
        "exp": int((now + dt.timedelta(minutes=10)).timestamp()),
        "aud": "https://appleid.apple.com",
        "sub": settings.apple_oauth_client_id,
    }
    return jwt.encode(
        payload,
        settings.apple_private_key,
        algorithm="ES256",
        headers={"kid": settings.apple_key_id},
    )


def _append_redirect_params(url: str, params: dict[str, str]) -> str:
    parsed = urlparse(url)
    if parsed.fragment:
        fragment = parsed.fragment
        if "?" in fragment:
            fragment_path, fragment_query = fragment.split("?", 1)
        else:
            fragment_path, fragment_query = fragment, ""
        fragment_params = dict(parse_qsl(fragment_query))
        fragment_params.update(params)
        new_fragment = f"{fragment_path}?{urlencode(fragment_params)}"
        return urlunparse(parsed._replace(fragment=new_fragment))

    query = dict(parse_qsl(parsed.query))
    query.update(params)
    return urlunparse(parsed._replace(query=urlencode(query)))


def _build_oauth_authorize_url(config: dict[str, str], redirect_uri: str, state: str) -> str:
    params = {
        "client_id": config["client_id"],
        "redirect_uri": redirect_uri,
        "response_type": "code",
        "scope": config["scope"],
        "state": state,
    }
    if config["issuer"].startswith("https://login.microsoftonline.com"):
        params["prompt"] = "select_account"
    return f"{config['auth_url']}?{urlencode(params)}"


def _exchange_code_for_token(config: dict[str, str], code: str, redirect_uri: str) -> dict:
    data = {
        "client_id": config["client_id"],
        "code": code,
        "grant_type": "authorization_code",
        "redirect_uri": redirect_uri,
    }
    if config["issuer"] == "https://appleid.apple.com":
        data["client_secret"] = _apple_client_secret()
    else:
        data["client_secret"] = config["client_secret"]

    headers = {"Content-Type": "application/x-www-form-urlencoded"}
    with httpx.Client(timeout=10) as client:
        response = client.post(config["token_url"], data=data, headers=headers)
    if response.status_code >= 400:
        bad_request("OAuth token exchange failed")
    return response.json()


def _verify_id_token(config: dict[str, str], id_token: str) -> dict:
    with httpx.Client(timeout=10) as client:
        jwks = client.get(config["jwks_url"]).json()
    unverified_header = jwt.get_unverified_header(id_token)
    key = next((k for k in jwks.get("keys", []) if k.get("kid") == unverified_header.get("kid")), None)
    if not key:
        bad_request("OAuth token verification failed")

    try:
        claims = jwt.decode(
            id_token,
            key,
            algorithms=[unverified_header.get("alg", "RS256")],
            audience=config["client_id"],
            issuer=config["issuer"] if config["issuer"] != "https://login.microsoftonline.com/" else None,
            options={"verify_iss": config["issuer"] != "https://login.microsoftonline.com/"},
        )
    except Exception:
        bad_request("OAuth token verification failed")

    if config["issuer"] == "https://login.microsoftonline.com/":
        iss = claims.get("iss", "")
        if not iss.startswith("https://login.microsoftonline.com/"):
            bad_request("OAuth token verification failed")

    return claims


def _get_or_create_oauth_user(db: Session, provider: str, claims: dict) -> User:
    subject = claims.get("sub")
    if not subject:
        bad_request("OAuth token missing subject")

    account = db.execute(
        select(OAuthAccount).where(
            OAuthAccount.provider == provider,
            OAuthAccount.subject == subject,
        )
    ).scalar_one_or_none()
    if account:
        return account.user

    email = claims.get("email") or claims.get("preferred_username")
    user = None
    if email:
        user = db.execute(select(User).where(User.email == email)).scalar_one_or_none()

    if not user:
        if not email:
            bad_request("OAuth account missing email")
        base_username = email.split("@")[0]
        username = base_username
        suffix = 1
        while db.execute(select(UserProfile).where(UserProfile.username == username)).scalar_one_or_none():
            suffix += 1
            username = f"{base_username}{suffix}"
        user = User(
            email=email,
            password_hash=hash_password(secrets.token_urlsafe(32)),
            role="user",
            is_active=True,
        )
        user.profile = UserProfile(username=username, bio=None, avatar_url=None, links=None)
        db.add(user)
        db.flush()

    account = OAuthAccount(
        user_id=user.id,
        provider=provider,
        subject=subject,
        email=email,
    )
    db.add(account)
    db.flush()
    return user


@router.get("/oauth/{provider}/start")
def oauth_start(provider: str, redirect_uri: str, request: Request, db: Session = Depends(get_db)):
    config = _oauth_provider_config(provider)
    callback_url = str(request.url_for("oauth_callback", provider=provider))
    state = _encode_state({"provider": provider, "redirect_uri": redirect_uri})
    if config.get("mock"):
        user = _get_or_create_oauth_user(db, provider, _mock_claims(provider))
        token_out = _issue_tokens_for_user(db, user)
        if redirect_uri:
            return RedirectResponse(
                _append_redirect_params(
                    redirect_uri,
                    {
                        "access_token": token_out.access_token,
                        "refresh_token": token_out.refresh_token,
                        "token_type": "bearer",
                    },
                )
            )
        return token_out
    authorize_url = _build_oauth_authorize_url(config, callback_url, state)
    return RedirectResponse(authorize_url)


@router.get("/oauth/{provider}/callback", name="oauth_callback")
def oauth_callback(
    provider: str,
    request: Request,
    db: Session = Depends(get_db),
    code: str | None = None,
    state: str | None = None,
    error: str | None = None,
):
    if error:
        if state:
            data = _decode_state(state)
            redirect_uri = data.get("redirect_uri")
            if redirect_uri:
                return RedirectResponse(_append_redirect_params(redirect_uri, {"error": error}))
        bad_request(error)

    if not code or not state:
        bad_request("Missing OAuth response")

    data = _decode_state(state)
    if data.get("provider") != provider:
        bad_request("Invalid OAuth state")

    redirect_uri = data.get("redirect_uri")
    config = _oauth_provider_config(provider)
    if config.get("mock"):
        user = _get_or_create_oauth_user(db, provider, _mock_claims(provider))
        token_out = _issue_tokens_for_user(db, user)
        if redirect_uri:
            return RedirectResponse(
                _append_redirect_params(
                    redirect_uri,
                    {
                        "access_token": token_out.access_token,
                        "refresh_token": token_out.refresh_token,
                        "token_type": "bearer",
                    },
                )
            )
        return token_out
    callback_url = str(request.url_for("oauth_callback", provider=provider))
    token_response = _exchange_code_for_token(config, code, callback_url)
    id_token = token_response.get("id_token")
    if not id_token:
        bad_request("OAuth token missing id_token")

    claims = _verify_id_token(config, id_token)
    user = _get_or_create_oauth_user(db, provider, claims)
    token_out = _issue_tokens_for_user(db, user)

    if redirect_uri:
        return RedirectResponse(
            _append_redirect_params(
                redirect_uri,
                {
                    "access_token": token_out.access_token,
                    "refresh_token": token_out.refresh_token,
                    "token_type": "bearer",
                },
            )
        )

    return token_out
