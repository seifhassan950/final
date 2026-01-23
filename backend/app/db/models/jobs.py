from __future__ import annotations
import uuid, datetime as dt
from sqlalchemy import DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column
from app.db.base import Base

class AIJob(Base):
    __tablename__ = "ai_jobs"
    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False)
    status: Mapped[str] = mapped_column(String(32), index=True, default="queued", nullable=False)
    progress: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    prompt: Mapped[str] = mapped_column(Text, nullable=False)
    settings_json: Mapped[dict] = mapped_column(JSONB, default=dict, nullable=False)
    logs: Mapped[str | None] = mapped_column(Text, nullable=True)
    error: Mapped[str | None] = mapped_column(Text, nullable=True)
    timings: Mapped[dict] = mapped_column(JSONB, default=dict, nullable=False)
    # NOTE: attribute name cannot be "metadata" (reserved by SQLAlchemy Declarative).
    # Column name MUST remain "metadata" per the project spec.
    job_metadata: Mapped[dict] = mapped_column("metadata", JSONB, default=dict, nullable=False)
    output_image_key: Mapped[str | None] = mapped_column(Text, nullable=True)
    output_glb_key: Mapped[str | None] = mapped_column(Text, nullable=True)
    output_stl_key: Mapped[str | None] = mapped_column(Text, nullable=True)
    preview_keys: Mapped[list] = mapped_column(JSONB, default=list, nullable=False)
    created_at: Mapped[dt.datetime] = mapped_column(DateTime(timezone=True), default=lambda: dt.datetime.now(dt.timezone.utc), nullable=False)
    updated_at: Mapped[dt.datetime] = mapped_column(DateTime(timezone=True), default=lambda: dt.datetime.now(dt.timezone.utc), onupdate=lambda: dt.datetime.now(dt.timezone.utc), nullable=False)

class ScanJob(Base):
    __tablename__ = "scan_jobs"
    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False)
    status: Mapped[str] = mapped_column(String(32), index=True, default="created", nullable=False)
    progress: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    input_keys: Mapped[list] = mapped_column(JSONB, default=list, nullable=False)
    logs: Mapped[str | None] = mapped_column(Text, nullable=True)
    error: Mapped[str | None] = mapped_column(Text, nullable=True)
    # NOTE: attribute name cannot be "metadata" (reserved by SQLAlchemy Declarative).
    # Column name MUST remain "metadata" per the project spec.
    job_metadata: Mapped[dict] = mapped_column("metadata", JSONB, default=dict, nullable=False)
    output_glb_key: Mapped[str | None] = mapped_column(Text, nullable=True)
    output_stl_key: Mapped[str | None] = mapped_column(Text, nullable=True)
    preview_keys: Mapped[list] = mapped_column(JSONB, default=list, nullable=False)
    created_at: Mapped[dt.datetime] = mapped_column(DateTime(timezone=True), default=lambda: dt.datetime.now(dt.timezone.utc), nullable=False)
    updated_at: Mapped[dt.datetime] = mapped_column(DateTime(timezone=True), default=lambda: dt.datetime.now(dt.timezone.utc), onupdate=lambda: dt.datetime.now(dt.timezone.utc), nullable=False)
