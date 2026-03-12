"""
AI quality gate: is the image good enough to process?
Returns usable (bool), blur/brightness scores from image data, and reasons if not usable.
"""
from PIL import Image
import numpy as np


def _brightness_score(image: Image.Image) -> float:
    """Mean luminance 0..1 (normalized)."""
    arr = np.array(image)
    if arr.ndim == 3:
        # RGB: use standard luminance weights
        lum = 0.299 * arr[:, :, 0].astype(np.float32) + 0.587 * arr[:, :, 1] + 0.114 * arr[:, :, 2]
    else:
        lum = arr.astype(np.float32)
    return float(np.clip(lum.mean() / 255.0, 0.0, 1.0))


def _blur_score(image: Image.Image) -> float:
    """Blur estimate 0..1 (0=sharp, 1=very blurry) via Laplacian variance on downscaled image.
    Downscaling avoids rejecting sharp intraoral images that have large smooth regions (teeth, gums).
    """
    gray = image.convert("L")
    w, h = gray.size
    max_side = 400
    if max(w, h) > max_side:
        ratio = max_side / max(w, h)
        new_w, new_h = int(w * ratio), int(h * ratio)
        gray = gray.resize((new_w, new_h), Image.Resampling.LANCZOS)
    arr = np.array(gray, dtype=np.float32)
    if arr.shape[0] < 3 or arr.shape[1] < 3:
        return 0.0
    # Laplacian (edge strength)
    lap = (
        arr[1:-1, 1:-1] * 4
        - arr[:-2, 1:-1]
        - arr[2:, 1:-1]
        - arr[1:-1, :-2]
        - arr[1:-1, 2:]
    )
    var = float(np.var(lap))
    # Normalize: intraoral images often have moderate variance; only very low = blurry
    # Scale tuned so sharp photos get blur < 0.5, truly blurry > 0.95
    max_var = 2500.0
    blur = 1.0 - min(var / max_var, 1.0)
    return max(0.0, blur)


def run_quality_gate(image: Image.Image) -> dict:
    brightness = _brightness_score(image)
    blur = _blur_score(image)
    # Only reject clearly dark or extremely blurry images (avoid false rejections on sharp intraoral photos)
    usable = brightness >= 0.2 and blur <= 0.97
    reasons = []
    if brightness < 0.2:
        reasons.append("Image trop sombre")
    if blur > 0.97:
        reasons.append("Image floue")
    return {
        "usable": usable,
        "blur_score": round(blur, 2),
        "brightness_score": round(brightness, 2),
        "mouth_visibility_score": 0.0,  # Would require real model (e.g. mouth detector)
        "reasons": reasons,
    }
