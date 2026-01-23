from __future__ import annotations
from pydantic import BaseModel, EmailStr, Field

class SignupIn(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    username: str = Field(min_length=3, max_length=50)

class LoginIn(BaseModel):
    email: EmailStr
    password: str

class TokenOut(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"

class RefreshIn(BaseModel):
    refresh_token: str

class EmailIn(BaseModel):
    email: EmailStr

class VerifyCodeIn(BaseModel):
    email: EmailStr
    code: str = Field(min_length=4, max_length=8)

class VerificationOut(BaseModel):
    detail: str = "ok"
    dev_code: str | None = None

class PasswordResetVerifyOut(BaseModel):
    reset_token: str

class PasswordResetIn(BaseModel):
    reset_token: str
    new_password: str = Field(min_length=8, max_length=128)

class ChangePasswordIn(BaseModel):
    new_password: str = Field(min_length=8, max_length=128)
