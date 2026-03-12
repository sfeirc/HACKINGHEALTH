"""Minimal tests for ML pipelines (no FastAPI)."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from PIL import Image
from app.pipelines.quality import run_quality_gate
from app.pipelines.screening import run_screening
from app.pipelines.postprocess import postprocess


def test_quality_gate_returns_usable():
    img = Image.new("RGB", (100, 100), color="white")
    r = run_quality_gate(img)
    assert r["usable"] is True
    assert "reasons" in r
    assert 0 <= r.get("blur_score", 0) <= 1


def test_screening_returns_list():
    img = Image.new("RGB", (100, 100), color="white")
    findings = run_screening(img)
    assert isinstance(findings, list)
    if findings:
        assert "region" in findings[0]
        assert "confidence" in findings[0]


def test_postprocess_returns_response():
    quality = {"usable": True, "blur_score": 0.1, "reasons": []}
    findings = [{"region": "test", "severity": "low", "confidence": 0.5}]
    r = postprocess(quality, findings)
    assert r.image_quality.usable
    assert r.screening.risk_level in ("low", "moderate", "high")
    assert r.recommendation is not None
    assert r.screening.has_cavity is True
    assert 0 <= r.screening.cavity_danger_score <= 100
