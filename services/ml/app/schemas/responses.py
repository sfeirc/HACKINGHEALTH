from pydantic import BaseModel
from typing import List, Optional


class ImageQualityResult(BaseModel):
    usable: bool
    blur_score: Optional[float] = None
    brightness_score: Optional[float] = None
    mouth_visibility_score: Optional[float] = None
    reasons: List[str] = []


class FindingResult(BaseModel):
    label: Optional[str] = None
    region: str
    severity: str  # low, moderate, high
    confidence: float


class ScreeningResult(BaseModel):
    risk_level: str  # low, moderate, high
    confidence: float
    findings: List[FindingResult] = []
    has_cavity: bool = False
    cavity_danger_score: int = 0  # 1-100


class RecommendationResult(BaseModel):
    action: str  # consult_dentist, retake_photo, no_action
    message: str


class AnalysisResponse(BaseModel):
    image_quality: ImageQualityResult
    screening: ScreeningResult
    recommendation: Optional[RecommendationResult] = None
