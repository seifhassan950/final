from __future__ import annotations

from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str = "postgresql+psycopg://r2v:r2v@db:5432/r2v"
    redis_url: str = "redis://redis:6379/0"

    s3_endpoint_url: str = "http://minio:9000"
    s3_public_endpoint_url: str | None = "http://localhost:9000"
    s3_access_key: str = "minioadmin"
    s3_secret_key: str = "minioadmin"
    s3_region: str = "us-east-1"
    s3_bucket_marketplace_models: str = "r2v-marketplace-models"
    s3_bucket_marketplace_thumbs: str = "r2v-marketplace-thumbs"
    s3_bucket_scans_raw: str = "r2v-user-scans-raw"
    s3_bucket_job_outputs: str = "r2v-job-outputs"

    jwt_secret: str = "dev_secret_change_in_prod"
    jwt_issuer: str = "r2v-backend"
    jwt_audience: str = "r2v-client"
    access_token_expires_min: int = 30
    refresh_token_expires_days: int = 30
    verification_code_expires_min: int = 15
    password_reset_expires_min: int = 30

    stripe_secret_key: str = ""
    stripe_webhook_secret: str = ""
    stripe_success_url: str = "http://localhost:55509/#/billing/success"
    stripe_cancel_url: str = "http://localhost:55509/#/billing/cancel"
    stripe_subscription_price_id: str = ""

    allowed_origins: str = "http://localhost:55509"
    allowed_origin_regex: str = r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$"
    env: str = "dev"
    log_level: str = "INFO"

    rate_limit_requests: int = 120
    rate_limit_window_seconds: int = 60
    max_upload_bytes: int = 104857600

settings = Settings()
