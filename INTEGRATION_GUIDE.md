# Integration Guide

## How to apply patches
1. **Unzip** `frontend_patch.zip` into the repo root (so it overlays `frontend/`).
2. **Unzip** `backend_patch.zip` into the repo root (so it overlays `backend/`).
3. **Unzip** `docs_patch.zip` into the repo root (this adds `CHANGELOG.md` and this file).
4. If prompted, allow overwrite/merge.

## Frontend (Flutter Web)

### Configuration
Use `--dart-define` for the API base URL:
- `R2V_API_BASE_URL` (required)
  - Example (local docker): `http://localhost:18001`
- `R2V_API_VERBOSE` (optional)
  - `true` enables request/response logging in debug builds.

### Run locally
```bash
cd frontend
flutter clean
flutter pub get
flutter run -d chrome --dart-define=R2V_API_BASE_URL=http://localhost:18001
```

## Backend (FastAPI)

### Configuration (.env)
Create `backend/.env` from `.env.example`, then edit as needed:
- `ALLOWED_ORIGINS` — comma-separated exact origins
- `ALLOWED_ORIGIN_REGEX` — regex to allow localhost with any port
- `VERIFICATION_CODE_EXPIRES_MIN`
- `PASSWORD_RESET_EXPIRES_MIN`

### Run locally
```bash
cd backend
cp .env.example .env
docker compose up --build
```

### Apply migrations
```bash
cd backend
alembic upgrade head
```

### Expected URLs
- API: `http://localhost:18001`
- OpenAPI docs: `http://localhost:18001/docs`

## Test checklist (UI → action → endpoint)

### Auth
- **Sign Up** → submit → `POST /auth/signup`, `POST /auth/verify/request`
- **Verify Code** → submit/resend → `POST /auth/verify/confirm`, `POST /auth/verify/request`
- **Sign In** → submit → `POST /auth/login`
- **Forgot Password** → submit → `POST /auth/password/forgot`
- **OTP Verification** → submit/resend → `POST /auth/password/verify`, `POST /auth/password/forgot`
- **Set New Password** → submit → `POST /auth/password/reset`
- **Complete Profile** → submit → `PATCH /me`, `POST /auth/password/change`

### Home
- **Dashboard stats + recent items** → load → `GET /dashboard/me`, `GET /ai/jobs`, `GET /scan/jobs`, `GET /marketplace/assets`, `GET /me`

### AI Studio
- **Send prompt** → create job → `POST /ai/jobs`

### Photo Scan
- **Upload/Finish** → create job & upload → `POST /scan/jobs`, `POST /scan/jobs/{job_id}/presign`, `PUT <presigned_url>`, `POST /scan/jobs/{job_id}/start`

### Marketplace
- **Browse assets** → load → `GET /marketplace/assets`
- **Details** → preview metadata → `GET /marketplace/assets`
- **Free download** → download → `GET /assets/{asset_id}/download`
- **Paid checkout** → checkout → `POST /billing/checkout/asset`

### Profile
- **Load profile** → `GET /me`
- **Edit profile** → `PATCH /me`

### Settings
- **Logout** → `POST /auth/logout`
- **Delete account** → `DELETE /me`
- **Manage Plan / Change** → `POST /billing/checkout/subscription`
