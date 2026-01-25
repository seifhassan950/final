from __future__ import annotations

import base64
from pathlib import Path
from urllib.parse import urljoin

import httpx

from app.core.config import settings

def _resolve_asset_url(response: httpx.Response, url: str) -> str:
    if url.startswith("http://") or url.startswith("https://"):
        return url
    base_url = str(response.request.url)
    return urljoin(base_url, url)

def _write_glb_from_response(response: httpx.Response, out_glb: Path) -> None:
    content_type = response.headers.get("content-type", "").lower()
    if "application/json" in content_type:
        payload = response.json()
        artifacts = payload.get("artifacts") if isinstance(payload, dict) else None
        if isinstance(artifacts, dict):
            artifact_url = artifacts.get("glb_url") or artifacts.get("model_url")
            if artifact_url:
                resolved_url = _resolve_asset_url(response, artifact_url)
                downloaded = httpx.get(resolved_url, timeout=settings.modal_api_timeout_s)
                downloaded.raise_for_status()
                out_glb.write_bytes(downloaded.content)
                return
        for key in ("glb_url", "url", "output_url", "model_url"):
            url = payload.get(key)
            if url:
                resolved_url = _resolve_asset_url(response, url)
                downloaded = httpx.get(resolved_url, timeout=settings.modal_api_timeout_s)
                downloaded.raise_for_status()
                out_glb.write_bytes(downloaded.content)
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
    with httpx.Client(timeout=settings.modal_api_timeout_s) as client:
        with image_path.open("rb") as handle:
            files = {"file": (image_path.name, handle, "image/png")}
            response = client.post(endpoint, files=files)
        response.raise_for_status()
        _write_glb_from_response(response, out_glb)

def _prompt_endpoints() -> list[str]:
    base = settings.modal_api_url.rstrip("/") + "/"
    configured = settings.modal_prompt_to_3d_path.lstrip("/")
    candidates = [
        configured,
        "generate-from-text",
        "text-to-3d",
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
    with httpx.Client(timeout=settings.modal_api_timeout_s) as client:
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
