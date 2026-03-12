from typing import List, Dict, Any
from app.schemas.responses import (
    AnalysisResponse,
    ImageQualityResult,
    ScreeningResult,
    FindingResult,
    RecommendationResult,
)


# Labels that indicate definite cavity (cavitation / carious lesion). "suspicious_caries_region" = possible early lesion, not yet cavity.
DEFINITE_CAVITY_LABELS = {"cavity", "carious_lesion", "definite_cavity"}


def postprocess(
    quality_result: dict, findings: List[Dict[str, Any]]
) -> AnalysisResponse:
    risk_level = "low"
    confidence = 0.0
    has_cavity = any(
        (f.get("label") or "").lower() in DEFINITE_CAVITY_LABELS for f in findings
    )
    cavity_danger_score = 0
    if findings:
        confidences = [f.get("confidence", 0) for f in findings]
        confidence = sum(confidences) / len(confidences) if confidences else 0
        if confidence >= 0.7:
            risk_level = "moderate"
        if confidence >= 0.85:
            risk_level = "high"
        # Danger score 1-100: severity (low=20, moderate=50, high=85) + confidence boost
        severity_base = {"low": 20, "moderate": 50, "high": 85}
        max_score = 0
        for f in findings:
            sev = f.get("severity", "low")
            conf = f.get("confidence", 0)
            base = severity_base.get(sev, 20)
            score = min(100, int(base + conf * 25))
            max_score = max(max_score, score)
        # Score can be non-zero for suspicious areas (moderate risk) even when no definite cavity
        cavity_danger_score = max(1, max_score) if (has_cavity or max_score > 0) else 0

    screening = ScreeningResult(
        risk_level=risk_level,
        confidence=round(confidence, 2),
        findings=[FindingResult(**f) for f in findings],
        has_cavity=has_cavity,
        cavity_danger_score=cavity_danger_score,
    )

    action = "no_action"
    message = "Aucun constat significatif."
    if risk_level == "moderate":
        action = "consult_dentist"
        message = "Une zone d'attention a été repérée. Il est recommandé de consulter un dentiste pour un contrôle."
    elif risk_level == "high":
        action = "consult_dentist"
        message = "Zones d'attention repérées. Veuillez consulter un dentiste."

    return AnalysisResponse(
        image_quality=ImageQualityResult(**quality_result),
        screening=screening,
        recommendation=RecommendationResult(action=action, message=message),
    )
