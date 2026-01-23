from __future__ import annotations
import boto3
from botocore.client import Config
from urllib.parse import urlparse, urlunparse
from app.core.config import settings

class S3Client:
    def __init__(self) -> None:
        self.client = boto3.client(
            "s3",
            endpoint_url=settings.s3_endpoint_url,
            aws_access_key_id=settings.s3_access_key,
            aws_secret_access_key=settings.s3_secret_key,
            region_name=settings.s3_region,
            config=Config(signature_version="s3v4"),
        )
        self.public_client = None
        if settings.s3_public_endpoint_url:
            self.public_client = boto3.client(
                "s3",
                endpoint_url=settings.s3_public_endpoint_url,
                aws_access_key_id=settings.s3_access_key,
                aws_secret_access_key=settings.s3_secret_key,
                region_name=settings.s3_region,
                config=Config(signature_version="s3v4"),
            )

    def _apply_public_endpoint(self, url: str) -> str:
        if not settings.s3_public_endpoint_url:
            return url
        public = urlparse(settings.s3_public_endpoint_url)
        original = urlparse(url)
        if not public.scheme or not public.netloc:
            return url
        public_path = public.path.rstrip("/")
        new_path = f"{public_path}{original.path}" if public_path else original.path
        return urlunparse(
            original._replace(
                scheme=public.scheme,
                netloc=public.netloc,
                path=new_path,
            )
        )

    def presign_put(
        self,
        bucket: str,
        key: str,
        expires: int = 3600,
        content_type: str | None = None,
    ) -> str:
        params = {"Bucket": bucket, "Key": key}
        if content_type:
            params["ContentType"] = content_type
        client = self.public_client or self.client
        return client.generate_presigned_url("put_object", Params=params, ExpiresIn=expires)

    def presign_get(self, bucket: str, key: str, expires: int = 3600) -> str:
        client = self.public_client or self.client
        url = client.generate_presigned_url("get_object", Params={"Bucket": bucket, "Key": key}, ExpiresIn=expires)
        if client is self.client:
            return self._apply_public_endpoint(url)
        return url

    def upload_file(self, local_path: str, bucket: str, key: str, content_type: str | None = None) -> None:
        extra = {"ContentType": content_type} if content_type else {}
        self.client.upload_file(local_path, bucket, key, ExtraArgs=extra)

s3 = S3Client()
