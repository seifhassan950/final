# R2V Studio — Flutter Web ↔ FastAPI Integration Report

## Summary (what was changed)
- Added a small, production-oriented Flutter API layer (base URL config, JSON client, error handling, JWT injection, and automatic refresh-on-401).
- Wired the **Sign In** and **Sign Up** screens to call the FastAPI backend auth endpoints (no more navigation-only auth).
- Fixed a backend bug in the auth router (missing `datetime` import) that prevented token refresh/logout from working.
- Improved FastAPI CORS so Flutter Web can call the API from **any localhost port** during dev, plus configurable exact origins for production.

---

## Files changed

### NEW files
**Frontend (Flutter Web)**
- `lib/api/api_config.dart`
- `lib/api/api_client.dart`
- `lib/api/api_exception.dart`
- `lib/api/auth_service.dart`
- `lib/api/token_pair.dart`
- `lib/api/token_storage.dart`
- `lib/api/token_storage_stub.dart`
- `lib/api/token_storage_web.dart`

### MODIFIED files
**Frontend (Flutter Web)**
- `lib/screens/signin.dart`
- `lib/screens/signup.dart`

**Backend (FastAPI)**
- `app/api/routers/auth.py`
- `app/core/config.py`
- `app/main.py`
- `.env.example`

---

## Backend endpoints used by the frontend
Base URL: `http://<host>:<port>` (default dev host port is **18001** via docker compose)

Auth:
- `POST /auth/signup`  → returns `{access_token, refresh_token}`
- `POST /auth/login`   → returns `{access_token, refresh_token}`
- `POST /auth/refresh` → returns `{access_token, refresh_token}`
- `POST /auth/logout`  → clears refresh token

User:
- `GET /me` (requires `Authorization: Bearer <access_token>`)

---

## Configuration / Environment variables

### Frontend (Flutter)
Set via `--dart-define`:
- `R2V_API_BASE_URL` (required)
  - Example (local docker): `http://localhost:18001`
- `R2V_API_VERBOSE` (optional)
  - `true` to print request logs in debug

### Backend (FastAPI)
Set in `.env` (docker compose reads it):
- `API_PORT` (host port mapped to container `:8000`)
  - default: `18001`
- `ALLOWED_ORIGINS` (comma-separated exact origins, recommended for production)
  - example: `https://your-frontend.example.com`
- `ALLOWED_ORIGIN_REGEX` (regex for dev/localhost)
  - default provided in `.env.example`:
    `^https?://(localhost|127\.0\.0\.1)(:\d+)?$`

---

## Step-by-step run instructions

### 1) Run the backend (docker)
From `backend/`:
1. Copy env file:
   - `cp .env.example .env`
2. Build + start:
   - `docker compose up --build`
3. Confirm API is reachable:
   - Open: `http://localhost:18001/docs`

### 2) Run the frontend (Flutter Web)
From `frontend/`:
1. Install deps:
   - `flutter clean`
   - `flutter pub get`
2. Run in Chrome with backend base URL:
   - `flutter run -d chrome --dart-define=R2V_API_BASE_URL=http://localhost:18001`

### Production notes
- Backend: deploy as usual (Docker/VM/Kubernetes) and set `ALLOWED_ORIGINS` to your deployed Flutter Web origin.
- Frontend: build with:
  - `flutter build web --release --dart-define=R2V_API_BASE_URL=https://your-api.example.com`

---

## Verification checklist (what to click/test)
1. **Backend health**
   - `http://localhost:18001/docs` loads
2. **Sign Up works**
   - Open the app → go to **Sign Up**
   - Enter username + email + password → **Sign Up**
   - App should navigate to **Complete Profile**
3. **Sign In works**
   - Go to **Sign In**
   - Enter the same email + password → **Sign In**
   - App should navigate to **Home**
4. **Bad credentials handling**
   - Try a wrong password → should show a SnackBar with backend error detail
5. **CORS**
   - Confirm no browser console CORS errors when calling auth endpoints

---

## Notes on token handling
- Tokens are stored:
  - **Remember Me ON**  → persistent browser storage (localStorage)
  - **Remember Me OFF** → session-only storage (sessionStorage)
- All authenticated requests automatically include `Authorization: Bearer <access_token>`.
- If the API returns **401**, the client automatically calls `POST /auth/refresh` once and retries.

---

## Packaging (multi-part ZIPs)
Because the Flutter repo contains large demo `.glb` files under `frontend/assets/models/`, the deliverable is split into multiple ZIP parts.

To reconstruct the full combined folder:
1. Create an empty folder (e.g. `r2v_linked/`).
2. Extract **part1** into that folder.
3. Extract **part2 → part5** into the **same** folder (overwrite/merge if prompted).

After extraction you should have:
- `frontend/` (full Flutter project, including `assets/models/*.glb`)
- `backend/` (FastAPI project)
- `INTEGRATION_REPORT.md`
