#!/usr/bin/env sh
set -eu

# Configure alias
mc alias set local "${S3_ENDPOINT_URL}" "${S3_ACCESS_KEY}" "${S3_SECRET_KEY}"

# Create buckets (idempotent)
mc mb --ignore-existing "local/${S3_BUCKET_MARKETPLACE_MODELS}"
mc mb --ignore-existing "local/${S3_BUCKET_MARKETPLACE_THUMBS}"
mc mb --ignore-existing "local/${S3_BUCKET_SCANS_RAW}"
mc mb --ignore-existing "local/${S3_BUCKET_JOB_OUTPUTS}"

echo "MinIO buckets ensured."
