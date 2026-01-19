from __future__ import annotations
from pydantic import BaseModel, Field
from typing import Any

class AIJobCreateIn(BaseModel):
    prompt: str = Field(min_length=1, max_length=2000)
    settings: dict[str, Any] = Field(default_factory=dict)

class ScanJobCreateIn(BaseModel):
    kind: str = Field(default="photos", description="photos|zip")

class ExportIn(BaseModel):
    formats: list[str] = Field(default_factory=lambda: ["glb", "stl"])

class JobOut(BaseModel):
    id: str
    status: str
    progress: int
    created_at: str
    updated_at: str | None = None
    prompt: str | None = None
    metadata: dict[str, Any] = Field(default_factory=dict)
    output_glb_key: str | None = None
    output_stl_key: str | None = None
    output_image_key: str | None = None
    preview_keys: list[str] = Field(default_factory=list)
    error: str | None = None

class DownloadOut(BaseModel):
    url: str
    expires_in: int
