from __future__ import annotations
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import select, desc
from app.api.deps import get_db, get_current_user
from app.api.schemas.jobs import AIJobCreateIn, JobOut, DownloadOut
from app.core.errors import not_found, forbidden
from app.db.models.jobs import AIJob
from app.workers.tasks import ai_generate_task
from app.services.s3 import s3
from app.core.config import settings

router = APIRouter()

def to_job_out(j: AIJob) -> JobOut:
    return JobOut(
        id=str(j.id), status=j.status, progress=j.progress,
        created_at=j.created_at.isoformat(), updated_at=j.updated_at.isoformat() if j.updated_at else None,
        prompt=j.prompt,
        metadata=j.job_metadata or {}, output_glb_key=j.output_glb_key, output_stl_key=j.output_stl_key,
        output_image_key=j.output_image_key, preview_keys=j.preview_keys or [], error=j.error
    )

@router.post("/jobs", response_model=JobOut)
def create_job(payload: AIJobCreateIn, db: Session = Depends(get_db), user = Depends(get_current_user)):
    job = AIJob(user_id=user.id, prompt=payload.prompt, settings_json=payload.settings, status="queued", progress=0)
    db.add(job); db.commit(); db.refresh(job)
    ai_generate_task.delay(str(job.id))
    return to_job_out(job)

@router.get("/jobs", response_model=list[JobOut])
def list_jobs(limit: int = 20, offset: int = 0, db: Session = Depends(get_db), user = Depends(get_current_user)):
    q = select(AIJob).where(AIJob.user_id == user.id).order_by(desc(AIJob.created_at)).limit(limit).offset(offset)
    items = db.execute(q).scalars().all()
    return [to_job_out(j) for j in items]

@router.get("/jobs/{job_id}", response_model=JobOut)
def get_job(job_id: str, db: Session = Depends(get_db), user = Depends(get_current_user)):
    j = db.get(AIJob, job_id)
    if not j: not_found()
    if j.user_id != user.id: forbidden()
    return to_job_out(j)

@router.get("/jobs/{job_id}/download/glb", response_model=DownloadOut)
def download_glb(job_id: str, db: Session = Depends(get_db), user = Depends(get_current_user)):
    j = db.get(AIJob, job_id)
    if not j: not_found()
    if j.user_id != user.id: forbidden()
    if not j.output_glb_key: not_found("No GLB yet")
    url = s3.presign_get(settings.s3_bucket_job_outputs, j.output_glb_key, expires=900)
    return DownloadOut(url=url, expires_in=900)
