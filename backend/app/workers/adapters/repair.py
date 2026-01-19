from __future__ import annotations
from pathlib import Path

def repair_mesh(in_glb: Path, out_glb: Path) -> None:
    # Placeholder: replace with Trimesh/MeshLab/PyMeshLab repair + hole filling
    out_glb.write_bytes(in_glb.read_bytes())
