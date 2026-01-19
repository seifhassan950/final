from __future__ import annotations
from pydantic import BaseModel, EmailStr, Field

class MeOut(BaseModel):
    id: str
    email: EmailStr
    role: str
    username: str
    bio: str | None = None
    avatar_url: str | None = None
    links: str | None = None

class MeUpdateIn(BaseModel):
    username: str | None = Field(default=None, min_length=3, max_length=50)
    bio: str | None = None
    avatar_url: str | None = None
    links: str | None = None
