from __future__ import annotations
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import select, desc
from app.api.deps import get_db, get_current_user
from app.core.errors import not_found
from app.db.models.social import Notification

router = APIRouter()

@router.get("", response_model=list[dict])
def list_notifications(limit: int = 50, offset: int = 0, db: Session = Depends(get_db), user = Depends(get_current_user)):
    q = select(Notification).where(Notification.user_id == user.id).order_by(desc(Notification.created_at)).limit(limit).offset(offset)
    items = db.execute(q).scalars().all()
    return [{"id": str(n.id), "type": n.type, "payload": n.payload_json, "is_read": n.is_read, "created_at": n.created_at.isoformat()} for n in items]

@router.post("/{notif_id}/read")
def mark_read(notif_id: str, db: Session = Depends(get_db), user = Depends(get_current_user)):
    n = db.get(Notification, notif_id)
    if not n or n.user_id != user.id:
        not_found()
    n.is_read = True
    db.commit()
    return {"detail": "ok"}
