# R2V Studio Backend (FastAPI + Postgres + Redis + MinIO + Celery + Stripe)

Self-hostable, zero/low-budget backend for the R2V Studio graduation project.

## Local run
```bash
cp .env.example .env
docker compose up --build
```
API: http://localhost:${API_PORT:-18001}/docs  
MinIO: internal-only (not published to host to avoid port conflicts).

## Notes
- AI/Photogrammetry integrations are implemented as adapter interfaces with safe placeholders.
  Replace the adapters in `app/workers/adapters/` with your real Stable Diffusion / Hunyuan3D-2 / repair / photogrammetry code.

### Modal AI integration
The image-to-3D adapter now calls a Modal-hosted FastAPI app. Configure these in `backend/.env` if your endpoints differ:
- `MODAL_API_URL` (base URL, defaults to the provided Modal app)
- `MODAL_IMAGE_TO_3D_PATH` (default `/generate`)
- `MODAL_PROMPT_TO_3D_PATH` (default `/generate-from-text`)
- `MODAL_API_TIMEOUT_S` (long-running GPU jobs; default 900 seconds)

AI jobs support optional image uploads by sending `settings.image_base64`, `settings.image_filename`,
and (optionally) `settings.image_mime`. When an image is provided, the backend posts it to the Modal
image-to-3D endpoint; otherwise it uses the prompt-to-3D endpoint for text-only jobs.


### Expose MinIO (optional)
If you really want to open the MinIO Console in your browser, edit `docker-compose.yml` and add a `ports:` section under `minio:` like:
```yaml
ports:
  - "9000:9000"   # API
  - "9001:9001"   # Console
```
Then re-run `docker compose up --build`.
