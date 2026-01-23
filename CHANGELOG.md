# Changelog

## Summary
- Wired Flutter Web screens to real backend services (auth verification, password reset, marketplace, AI jobs, scan uploads, profile, billing).
- Expanded FastAPI auth and marketplace to support verification/password reset and asset metadata/preview URLs.
- Added scan presign request body support, profile deletion, and dashboard/job payload updates.

## Files changed

### NEW
**Frontend (Flutter Web)**
- `frontend/lib/api/ai_jobs_service.dart` — AI job create/list client models.
- `frontend/lib/api/billing_service.dart` — subscription checkout client.
- `frontend/lib/api/dashboard_service.dart` — dashboard stats client.
- `frontend/lib/api/email_verification_service.dart` — email verification request/confirm client.
- `frontend/lib/api/marketplace_service.dart` — marketplace asset models and download/checkout client.
- `frontend/lib/api/password_reset_service.dart` — password reset request/verify/reset client.
- `frontend/lib/api/profile_service.dart` — profile fetch/update/delete client.
- `frontend/lib/api/scan_jobs_service.dart` — scan job create/upload/start client.

**Backend (FastAPI)**
- `backend/alembic/versions/0002_verification_codes.py` — adds verification_codes table for email/password flows.

### MODIFIED
**Frontend (Flutter Web)**
- `frontend/lib/api/api_client.dart` — request logging, PATCH, and list decoding support.
- `frontend/lib/api/auth_service.dart` — remember-me persistence + password change.
- `frontend/lib/api/r2v_api.dart` — exported new service singletons.
- `frontend/lib/api/token_store_impl.dart` — persist/session storage support.
- `frontend/lib/api/token_store_memory.dart` — persist flag support.
- `frontend/lib/api/token_store_web.dart` — session vs local storage handling.
- `frontend/lib/main.dart` — routes updated for new models and reset tokens.
- `frontend/lib/payments/payment_screen.dart` — live checkout/download handling.
- `frontend/lib/screens/ai_chat_screen.dart` — AI job creation wired to backend.
- `frontend/lib/screens/complete_profile.dart` — profile update + password change.
- `frontend/lib/screens/explore_screen.dart` — marketplace data from API + downloads.
- `frontend/lib/screens/forgot_password.dart` — password reset request.
- `frontend/lib/screens/home_screen.dart` — dashboard stats + recent items from API.
- `frontend/lib/screens/otp_verification.dart` — reset code verify/resend.
- `frontend/lib/screens/photo_scan_guided.dart` — scan job upload/start.
- `frontend/lib/screens/profile_screen.dart` — profile load/update + avatar persistence.
- `frontend/lib/screens/set_new_password.dart` — reset password via API.
- `frontend/lib/screens/settings_screen.dart` — logout/delete/checkout actions.
- `frontend/lib/screens/signin.dart` — remember-me persistence.
- `frontend/lib/screens/signup.dart` — signup verification flow.
- `frontend/lib/screens/verify_code.dart` — email verification + resend.

**Backend (FastAPI)**
- `backend/.env.example` — added verification/password reset and CORS regex.
- `backend/app/api/routers/ai_jobs.py` — expose prompt in job output.
- `backend/app/api/routers/auth.py` — email verification, password reset, change-password.
- `backend/app/api/routers/marketplace.py` — creator username, thumb/preview URLs.
- `backend/app/api/routers/me.py` — delete account endpoint.
- `backend/app/api/routers/scan_jobs.py` — presign request body support.
- `backend/app/api/schemas/auth.py` — new request/response schemas.
- `backend/app/api/schemas/common.py` — presign request schema.
- `backend/app/api/schemas/jobs.py` — prompt in job output.
- `backend/app/api/schemas/marketplace.py` — thumb/preview URLs.
- `backend/app/core/config.py` — verification/password reset and CORS regex settings.
- `backend/app/db/models/__init__.py` — register verification model.
- `backend/app/db/models/user.py` — verification code table model.
- `backend/app/main.py` — CORS regex config.
