"""
Service ML Dent ta Maison : qualité d'image et dépistage caries.
Expose POST /infer (image base64) et GET /health.
"""
from fastapi import FastAPI
from app.api.routes import router

app = FastAPI(title="Dent ta Maison — Service ML", version="1.0.0")
app.include_router(router, prefix="", tags=["infer"])


@app.get("/health")
def health():
    """Santé du service (pour load balancer / orchestration)."""
    return {"status": "ok"}
