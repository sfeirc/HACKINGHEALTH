"""
AI cavity detection: detect dental cavity and return findings (region, severity, confidence).
Used to compute has_cavity and cavity_danger_score (1–100 gravity) in postprocess.
Returns empty list until a real model (e.g. MONAI/ONNX caries detection) is integrated.
"""
from PIL import Image
from typing import List, Dict, Any


def run_screening(image: Image.Image) -> List[Dict[str, Any]]:
    # No mock data: return empty until real model is connected
    return []
