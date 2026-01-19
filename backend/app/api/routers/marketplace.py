from __future__ import annotations
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import select, desc, or_, func
from app.api.deps import get_db, get_current_user
from app.api.schemas.marketplace import AssetOut, AssetCreateIn, AssetUpdateIn, EntitlementOut, AssetPresignIn, AssetPresignOut
from app.core.errors import not_found, forbidden, bad_request, conflict
from app.db.models.marketplace import Asset, RecentlyViewed
from app.db.models.social import Like, Save
from app.db.models.user import UserProfile
from app.services.entitlements import is_entitled_to_asset
from app.services.s3 import s3
from app.core.config import settings
from uuid import UUID
import datetime as dt
import uuid

router = APIRouter()

def _thumb_url(a: Asset) -> str | None:
    if not a.thumb_object_key:
        return None
    return s3.presign_get(settings.s3_bucket_marketplace_thumbs, a.thumb_object_key, expires=900)

def _preview_url(a: Asset) -> str | None:
    if not a.preview_object_keys:
        return None
    key = a.preview_object_keys[0]
    return s3.presign_get(settings.s3_bucket_marketplace_models, key, expires=900)

def _set_like_count(a: Asset, db: Session) -> None:
    count = db.execute(select(func.count()).select_from(Like).where(Like.asset_id == a.id)).scalar_one()
    meta = dict(a.meta_json or {})
    meta["likes"] = count
    a.meta_json = meta

def to_out(a: Asset, creator_username: str | None = None) -> AssetOut:
    meta = dict(a.meta_json or {})
    if creator_username:
        meta.setdefault("creator_username", creator_username)
    meta.setdefault("likes", meta.get("likes", 0))
    return AssetOut(
        id=str(a.id), title=a.title, description=a.description, tags=a.tags or [], category=a.category, style=a.style,
        creator_id=str(a.creator_id), is_paid=a.is_paid, price=a.price, currency=a.currency,
        visibility=a.visibility, published_at=a.published_at.isoformat() if a.published_at else None,
        thumb_object_key=a.thumb_object_key, thumb_url=_thumb_url(a),
        model_object_key=a.model_object_key, preview_url=_preview_url(a),
        metadata=meta,
    )

@router.get("/assets", response_model=list[AssetOut])
def list_assets(q: str | None = None, category: str | None = None, style: str | None = None,
               limit: int = 20, offset: int = 0, db: Session = Depends(get_db)):
    stmt = select(Asset).where(Asset.visibility == "published")
    if q:
        like = f"%{q}%"
        stmt = stmt.where(or_(Asset.title.ilike(like), Asset.description.ilike(like)))
    if category:
        stmt = stmt.where(Asset.category == category)
    if style:
        stmt = stmt.where(Asset.style == style)
    stmt = stmt.order_by(desc(Asset.published_at)).limit(limit).offset(offset)
    items = db.execute(stmt).scalars().all()
    creator_ids = {a.creator_id for a in items}
    profiles = {}
    if creator_ids:
        rows = db.execute(select(UserProfile).where(UserProfile.user_id.in_(creator_ids))).scalars().all()
        profiles = {p.user_id: p.username for p in rows}
    return [to_out(a, profiles.get(a.creator_id)) for a in items]

@router.get("/assets/me", response_model=list[AssetOut])
def list_my_assets(db: Session = Depends(get_db), user = Depends(get_current_user)):
    items = db.execute(
        select(Asset).where(Asset.creator_id == user.id).order_by(desc(Asset.created_at))
    ).scalars().all()
    prof = db.execute(select(UserProfile).where(UserProfile.user_id == user.id)).scalar_one_or_none()
    creator_name = prof.username if prof else None
    return [to_out(a, creator_name) for a in items]

@router.get("/assets/saved", response_model=list[AssetOut])
def list_saved_assets(db: Session = Depends(get_db), user = Depends(get_current_user)):
    stmt = (
        select(Asset)
        .join(Save, Save.asset_id == Asset.id)
        .where(Save.user_id == user.id)
        .where(or_(Asset.visibility == "published", Asset.creator_id == user.id))
        .order_by(desc(Save.created_at))
    )
    items = db.execute(stmt).scalars().all()
    creator_ids = {a.creator_id for a in items}
    profiles = {}
    if creator_ids:
        rows = db.execute(select(UserProfile).where(UserProfile.user_id.in_(creator_ids))).scalars().all()
        profiles = {p.user_id: p.username for p in rows}
    return [to_out(a, profiles.get(a.creator_id)) for a in items]

@router.get("/assets/liked", response_model=list[AssetOut])
def list_liked_assets(db: Session = Depends(get_db), user = Depends(get_current_user)):
    stmt = (
        select(Asset)
        .join(Like, Like.asset_id == Asset.id)
        .where(Like.user_id == user.id)
        .where(or_(Asset.visibility == "published", Asset.creator_id == user.id))
        .order_by(desc(Like.created_at))
    )
    items = db.execute(stmt).scalars().all()
    creator_ids = {a.creator_id for a in items}
    profiles = {}
    if creator_ids:
        rows = db.execute(select(UserProfile).where(UserProfile.user_id.in_(creator_ids))).scalars().all()
        profiles = {p.user_id: p.username for p in rows}
    return [to_out(a, profiles.get(a.creator_id)) for a in items]

@router.get("/assets/user/{user_id}", response_model=list[AssetOut])
def list_user_assets(user_id: UUID, db: Session = Depends(get_db), user = Depends(get_current_user)):
    stmt = (
        select(Asset)
        .where(Asset.creator_id == user_id)
        .where(or_(Asset.visibility == "published", Asset.creator_id == user.id))
        .order_by(desc(Asset.created_at))
    )
    items = db.execute(stmt).scalars().all()
    prof = db.execute(select(UserProfile).where(UserProfile.user_id == user_id)).scalar_one_or_none()
    creator_name = prof.username if prof else None
    return [to_out(a, creator_name) for a in items]

@router.post("/assets/presign", response_model=AssetPresignOut)
def presign_asset(payload: AssetPresignIn, user = Depends(get_current_user)):
    kind = payload.kind.lower()
    if kind not in {"model", "thumb"}:
        bad_request("kind must be model|thumb")
    bucket = settings.s3_bucket_marketplace_models if kind == "model" else settings.s3_bucket_marketplace_thumbs
    key = f"{user.id}/marketplace/{kind}/{uuid.uuid4()}_{payload.filename}"
    content_type = payload.content_type if kind == "thumb" else None
    url = s3.presign_put(
        bucket,
        key,
        expires=3600,
        content_type=content_type,
    )
    return AssetPresignOut(url=url, key=key)

@router.post("/assets", response_model=AssetOut)
def create_asset(payload: AssetCreateIn, db: Session = Depends(get_db), user = Depends(get_current_user)):
    a = Asset(
        creator_id=user.id,
        title=payload.title,
        description=payload.description,
        tags=payload.tags,
        category=payload.category,
        style=payload.style,
        is_paid=payload.is_paid,
        price=payload.price,
        currency=payload.currency,
        license=payload.license,
        visibility="draft",
        model_object_key=payload.model_object_key,
        thumb_object_key=payload.thumb_object_key,
        preview_object_keys=payload.preview_object_keys,
        meta_json=payload.metadata,
    )
    db.add(a); db.commit(); db.refresh(a)
    prof = db.execute(select(UserProfile).where(UserProfile.user_id == user.id)).scalar_one_or_none()
    creator_name = prof.username if prof else None
    return to_out(a, creator_name)

@router.get("/assets/{asset_id}", response_model=AssetOut)
def get_asset(asset_id: str, db: Session = Depends(get_db), user = Depends(get_current_user)):
    a = db.get(Asset, asset_id)
    if not a: not_found()
    # viewing allowed if published or owner
    if a.visibility != "published" and a.creator_id != user.id:
        forbidden()
    # track recently viewed
    rv = db.execute(select(RecentlyViewed).where(RecentlyViewed.user_id == user.id, RecentlyViewed.asset_id == a.id)).scalar_one_or_none()
    if rv:
        rv.last_viewed_at = dt.datetime.now(dt.timezone.utc)
    else:
        db.add(RecentlyViewed(user_id=user.id, asset_id=a.id))
    db.commit()
    prof = db.execute(select(UserProfile).where(UserProfile.user_id == a.creator_id)).scalar_one_or_none()
    creator_name = prof.username if prof else None
    return to_out(a, creator_name)

@router.patch("/assets/{asset_id}", response_model=AssetOut)
def update_asset(asset_id: str, payload: AssetUpdateIn, db: Session = Depends(get_db), user = Depends(get_current_user)):
    a = db.get(Asset, asset_id)
    if not a: not_found()
    if a.creator_id != user.id: forbidden()
    for field, value in payload.model_dump(exclude_unset=True).items():
        # "metadata" is the API field name; the ORM attribute is "meta_json".
        if field == "metadata":
            setattr(a, "meta_json", value)
        else:
            setattr(a, field, value)
    db.commit(); db.refresh(a)
    prof = db.execute(select(UserProfile).where(UserProfile.user_id == user.id)).scalar_one_or_none()
    creator_name = prof.username if prof else None
    return to_out(a, creator_name)

@router.post("/assets/{asset_id}/publish", response_model=AssetOut)
def publish(asset_id: str, db: Session = Depends(get_db), user = Depends(get_current_user)):
    a = db.get(Asset, asset_id)
    if not a: not_found()
    if a.creator_id != user.id: forbidden()
    if not a.model_object_key:
        bad_request("model_object_key is required")
    a.visibility = "published"
    a.published_at = dt.datetime.now(dt.timezone.utc)
    db.commit(); db.refresh(a)
    prof = db.execute(select(UserProfile).where(UserProfile.user_id == user.id)).scalar_one_or_none()
    creator_name = prof.username if prof else None
    return to_out(a, creator_name)

@router.post("/assets/{asset_id}/like")
def like_asset(asset_id: str, db: Session = Depends(get_db), user = Depends(get_current_user)):
    a = db.get(Asset, asset_id)
    if not a: not_found()
    existing = db.execute(select(Like).where(Like.user_id == user.id, Like.asset_id == a.id)).scalar_one_or_none()
    if existing:
        conflict("Already liked")
    db.add(Like(user_id=user.id, asset_id=a.id))
    db.flush()
    _set_like_count(a, db)
    db.commit()
    return {"detail": "ok"}

@router.delete("/assets/{asset_id}/like")
def unlike_asset(asset_id: str, db: Session = Depends(get_db), user = Depends(get_current_user)):
    a = db.get(Asset, asset_id)
    if not a: not_found()
    like = db.execute(select(Like).where(Like.user_id == user.id, Like.asset_id == a.id)).scalar_one_or_none()
    if not like:
        not_found("Like not found")
    db.delete(like)
    db.flush()
    _set_like_count(a, db)
    db.commit()
    return {"detail": "ok"}

@router.post("/assets/{asset_id}/save")
def save_asset(asset_id: str, db: Session = Depends(get_db), user = Depends(get_current_user)):
    a = db.get(Asset, asset_id)
    if not a: not_found()
    existing = db.execute(select(Save).where(Save.user_id == user.id, Save.asset_id == a.id)).scalar_one_or_none()
    if existing:
        conflict("Already saved")
    db.add(Save(user_id=user.id, asset_id=a.id))
    db.commit()
    return {"detail": "ok"}

@router.delete("/assets/{asset_id}/save")
def unsave_asset(asset_id: str, db: Session = Depends(get_db), user = Depends(get_current_user)):
    a = db.get(Asset, asset_id)
    if not a: not_found()
    saved = db.execute(select(Save).where(Save.user_id == user.id, Save.asset_id == a.id)).scalar_one_or_none()
    if not saved:
        not_found("Save not found")
    db.delete(saved)
    db.commit()
    return {"detail": "ok"}

@router.delete("/assets/{asset_id}")
def delete_asset(asset_id: str, db: Session = Depends(get_db), user = Depends(get_current_user)):
    a = db.get(Asset, asset_id)
    if not a: not_found()
    if a.creator_id != user.id: forbidden()
    db.delete(a)
    db.commit()
    return {"detail": "ok"}

@router.get("/assets/{asset_id}/entitlement", response_model=EntitlementOut)
def entitlement(asset_id: str, db: Session = Depends(get_db), user = Depends(get_current_user)):
    a = db.get(Asset, asset_id)
    if not a: not_found()
    entitled, reason = is_entitled_to_asset(db, user.id, a)
    return EntitlementOut(asset_id=str(a.id), entitled=entitled, reason=reason)
