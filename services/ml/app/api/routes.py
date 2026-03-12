"""
Pipeline ML : Image → contrôle qualité → dépistage caries → score de gravité 1–100.

1. Contrôle qualité : l'image est-elle exploitable (netteté, luminosité, cadrage) ?
2. Si non : retour anticipé avec message pour l'utilisateur.
3. Dépistage : détection des caries et score de gravité 1–100.
4. Réponse : image_quality (usable + scores), screening (has_cavity, cavity_danger_score), recommendation.
"""
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from PIL import Image

from app.schemas.responses import AnalysisResponse
from app.pipelines.quality import run_quality_gate
from app.pipelines.preprocess import preprocess
from app.pipelines.screening import run_screening
from app.pipelines.postprocess import postprocess

router = APIRouter()


class InferRequest(BaseModel):
    image: str  # base64


def run_pipeline(img: Image.Image) -> AnalysisResponse:
    """Exécute le pipeline complet : qualité → dépistage caries → score 1–100."""
    quality_result = run_quality_gate(img)
    if not quality_result["usable"]:
        return postprocess(quality_result, [])
    preprocessed = preprocess(img)
    findings = run_screening(preprocessed)
    return postprocess(quality_result, findings)


@router.post("/infer", response_model=AnalysisResponse)
def infer(request: InferRequest) -> AnalysisResponse:
    """Inférence : image base64 en entrée, résultat d'analyse (qualité + dépistage) en sortie."""
    if not request.image:
        raise HTTPException(status_code=400, detail="Image manquante")
    import base64
    from io import BytesIO

    try:
        raw = base64.b64decode(request.image)
        img = Image.open(BytesIO(raw)).convert("RGB")
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Image invalide : {e}")

    return run_pipeline(img)
