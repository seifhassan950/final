from __future__ import annotations
import tempfile, datetime as dt
from pathlib import Path
from sqlalchemy.orm import Session
from app.workers.celery_app import celery_app
from app.db.session import SessionLocal
from app.db.models.jobs import AIJob, ScanJob
from app.services.s3 import s3
from app.core.config import settings
from app.workers.adapters.image_gen import generate_image
from app.workers.adapters.model_gen import image_to_3d
from app.workers.adapters.repair import repair_mesh
from app.workers.adapters.photogrammetry import reconstruct_from_images

def _db() -> Session:
    return SessionLocal()

def _mark_failed(job, err: str, db: Session):
    job.status = "failed"
    job.error = err
    job.updated_at = dt.datetime.now(dt.timezone.utc)
    db.commit()

@celery_app.task(name="app.workers.tasks.ai_generate_task")
def ai_generate_task(job_id: str):
    db = _db()
    job = db.get(AIJob, job_id)
    if not job:
        return
    try:
        job.status = "running"; job.progress = 5; db.commit()

        with tempfile.TemporaryDirectory() as td:
            td = Path(td)
            img_path = td / "out.png"
            glb_raw = td / "raw.glb"
            glb_fixed = td / "fixed.glb"

            generate_image(job.prompt, img_path)
            job.progress = 25; db.commit()

            image_to_3d(img_path, glb_raw)
            job.progress = 60; db.commit()

            repair_mesh(glb_raw, glb_fixed)
            job.progress = 80; db.commit()

            # Upload outputs
            out_key_img = f"{job.user_id}/{job.id}/outputs/out.png"
            out_key_glb = f"{job.user_id}/{job.id}/outputs/model.glb"
            s3.upload_file(str(img_path), settings.s3_bucket_job_outputs, out_key_img, content_type="image/png")
            s3.upload_file(str(glb_fixed), settings.s3_bucket_job_outputs, out_key_glb, content_type="model/gltf-binary")

            job.output_image_key = out_key_img
            job.output_glb_key = out_key_glb
            job.preview_keys = [out_key_img]
            job.status = "succeeded"; job.progress = 100
            job.updated_at = dt.datetime.now(dt.timezone.utc)
            db.commit()
    except Exception as e:
        _mark_failed(job, str(e), db)
    finally:
        db.close()

@celery_app.task(name="app.workers.tasks.scan_reconstruct_task")
def scan_reconstruct_task(job_id: str):
    db = _db()
    job = db.get(ScanJob, job_id)
    if not job:
        return
    try:
        job.status = "running"; job.progress = 5; db.commit()
        with tempfile.TemporaryDirectory() as td:
            td = Path(td)
            inputs = td / "inputs"; inputs.mkdir(parents=True, exist_ok=True)
            out_glb = td / "scan.glb"
            out_fixed = td / "scan_fixed.glb"

            # NOTE: placeholder doesn't download from S3 to save time/bandwidth.
            # In a real pipeline, download the input images (keys) to inputs/ then run reconstruction.
            reconstruct_from_images(inputs, out_glb)
            job.progress = 70; db.commit()

            repair_mesh(out_glb, out_fixed)
            job.progress = 85; db.commit()

            out_key_glb = f"{job.user_id}/{job.id}/outputs/scan.glb"
            s3.upload_file(str(out_fixed), settings.s3_bucket_job_outputs, out_key_glb, content_type="model/gltf-binary")
            job.output_glb_key = out_key_glb
            job.preview_keys = [out_key_glb]
            job.status = "succeeded"; job.progress = 100
            job.updated_at = dt.datetime.now(dt.timezone.utc)
            db.commit()
    except Exception as e:
        _mark_failed(job, str(e), db)
    finally:
        db.close()
