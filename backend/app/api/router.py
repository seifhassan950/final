from fastapi import APIRouter
from app.api.routers import auth, me, ai_jobs, scan_jobs, marketplace, assets_download, social, dashboard, notifications, billing, stripe_webhook

api_router = APIRouter()
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(me.router, tags=["me"])
api_router.include_router(ai_jobs.router, prefix="/ai", tags=["ai"])
api_router.include_router(scan_jobs.router, prefix="/scan", tags=["scan"])
api_router.include_router(marketplace.router, prefix="/marketplace", tags=["marketplace"])
api_router.include_router(assets_download.router, tags=["downloads"])
api_router.include_router(social.router, prefix="/social", tags=["social"])
api_router.include_router(dashboard.router, prefix="/dashboard", tags=["dashboard"])
api_router.include_router(notifications.router, prefix="/notifications", tags=["notifications"])
api_router.include_router(billing.router, prefix="/billing", tags=["billing"])
api_router.include_router(stripe_webhook.router, prefix="/stripe", tags=["stripe"])
