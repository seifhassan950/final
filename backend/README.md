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


### Expose MinIO (optional)
If you really want to open the MinIO Console in your browser, edit `docker-compose.yml` and add a `ports:` section under `minio:` like:
```yaml
ports:
  - "9000:9000"   # API
  - "9001:9001"   # Console
```
Then re-run `docker compose up --build`.
