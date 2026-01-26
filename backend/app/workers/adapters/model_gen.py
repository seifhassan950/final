from __future__ import annotations

import base64
import time
from pathlib import Path
from urllib.parse import urljoin

import httpx

from app.core.config import settings

def _download_with_retry(url: str, *, max_attempts: int | None = None) -> bytes:
    last_error: httpx.HTTPStatusError | None = None
    attempts = max_attempts or settings.modal_download_max_attempts
    for _ in range(attempts):
        response = httpx.get(url, timeout=settings.modal_api_timeout_s, follow_redirects=True)
        if response.status_code == 404:
            last_error = httpx.HTTPStatusError(
                f"Modal download not ready after {attempts} attempts: {url}",
                request=response.request,
                response=response,
            )
            time.sleep(settings.modal_download_retry_s)
            continue
        response.raise_for_status()
        return response.content
    if last_error:
        raise last_error
    raise ValueError(f"Modal download failed: {url}")

def _resolve_asset_url(response: httpx.Response, url: str) -> str:
    if url.startswith("http://") or url.startswith("https://"):
        return url
    base_url = str(response.request.url)
    return urljoin(base_url, url)

def _resolve_download_from_payload(payload: dict, response: httpx.Response) -> bytes | None:
    artifacts = payload.get("artifacts")
    if isinstance(artifacts, dict):
        artifact_url = artifacts.get("glb_url") or artifacts.get("model_url") or artifacts.get("download_url")
        if artifact_url:
            resolved_url = _resolve_asset_url(response, artifact_url)
            return _download_with_retry(resolved_url)
    if isinstance(artifacts, list):
        for artifact in artifacts:
            if not isinstance(artifact, dict):
                continue
            artifact_url = artifact.get("glb_url") or artifact.get("model_url") or artifact.get("download_url") or artifact.get("url")
            filename = artifact.get("filename") or artifact.get("file_name")
            if artifact_url and (not filename or filename.endswith(".glb")):
                resolved_url = _resolve_asset_url(response, artifact_url)
                return _download_with_retry(resolved_url)

    for key in ("glb_url", "url", "output_url", "model_url", "download_url"):
        url = payload.get(key)
        if url:
            resolved_url = _resolve_asset_url(response, url)
            return _download_with_retry(resolved_url)

    job_id = payload.get("job_id") or payload.get("id")
    if job_id:
        filename = (
            payload.get("filename")
            or payload.get("file_name")
            or payload.get("output_filename")
            or payload.get("output_file")
            or "model.glb"
        )
        download_url = urljoin(
            settings.modal_api_url.rstrip("/") + "/",
            f"download/{job_id}/{filename}",
        )
        return _download_with_retry(
            download_url,
            max_attempts=settings.modal_download_fallback_max_attempts,
        )
    return None

def _write_glb_from_response(response: httpx.Response, out_glb: Path) -> None:
    content_type = response.headers.get("content-type", "").lower()
    if "application/json" in content_type:
        payload = response.json()
        if not isinstance(payload, dict):
            raise ValueError("Modal response JSON must be an object")
        downloaded = _resolve_download_from_payload(payload, response)
        if downloaded is not None:
            out_glb.write_bytes(downloaded)
            return
        for key in ("glb_base64", "model_base64", "data"):
            encoded = payload.get(key)
            if encoded:
                out_glb.write_bytes(base64.b64decode(encoded))
                return
        raise ValueError("Modal response JSON missing GLB payload")

    if "model/gltf-binary" in content_type or "application/octet-stream" in content_type:
        out_glb.write_bytes(response.content)
        return

    raise ValueError(f"Unexpected Modal response type: {content_type}")

def image_to_3d(image_path: Path, out_glb: Path) -> None:
    if not settings.modal_api_url:
        raise ValueError("Modal API URL is not configured")

    endpoint = urljoin(settings.modal_api_url.rstrip("/") + "/", settings.modal_image_to_3d_path.lstrip("/"))
    with httpx.Client(timeout=settings.modal_api_timeout_s, follow_redirects=True) as client:
        with image_path.open("rb") as handle:
            files = {"file": (image_path.name, handle, "image/png")}
            response = client.post(endpoint, files=files)
        response.raise_for_status()
        _write_glb_from_response(response, out_glb)

def _prompt_endpoints() -> list[str]:
    base = settings.modal_api_url.rstrip("/") + "/"
    configured = settings.modal_prompt_to_3d_path.lstrip("/")
    image_path = settings.modal_image_to_3d_path.lstrip("/")
    candidates = [
        configured,
        image_path,
        "generate-from-text",
        "generate",
        "text-to-3d",
        "prompt-to-3d",
    ]
    seen = set()
    endpoints = []
    for path in candidates:
        if not path or path in seen:
            continue
        seen.add(path)
        endpoints.append(urljoin(base, path))
    return endpoints

def prompt_to_3d(prompt: str, out_glb: Path) -> None:
    if not settings.modal_api_url:
        raise ValueError("Modal API URL is not configured")

    payload = {"prompt": prompt}
    last_error: Exception | None = None
    with httpx.Client(timeout=settings.modal_api_timeout_s, follow_redirects=True) as client:
        for endpoint in _prompt_endpoints():
            response = client.post(endpoint, json=payload)
            if response.status_code == 404:
                last_error = httpx.HTTPStatusError(
                    f"Prompt endpoint not found: {endpoint}",
                    request=response.request,
                    response=response,
                )
                continue
            response.raise_for_status()
            _write_glb_from_response(response, out_glb)
            return
    if last_error:
        raise last_error
