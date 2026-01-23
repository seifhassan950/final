from __future__ import annotations
from pathlib import Path

def image_to_3d(image_path: Path, out_glb: Path) -> None:
    # Placeholder: replace with Hunyuan3D-2 pipeline
    out_glb.write_bytes(b"GLB_PLACEHOLDER")

def prompt_to_3d(prompt: str, out_glb: Path) -> None:
    # Placeholder: replace with text-to-3D generator (future work / optional)
    out_glb.write_bytes(b"GLB_PLACEHOLDER_FROM_PROMPT")
