"""Compatibility import for the active FastAPI complaint router.

The canonical model and training code live under app.ml so the trainer and
inference always use the same artifact format.
"""
from app.ml.classifier import predict_department as _predict_department


def predict_department(complaint_text: str) -> str:
    department, _confidence = _predict_department(complaint_text)
    return getattr(department, "value", str(department))
