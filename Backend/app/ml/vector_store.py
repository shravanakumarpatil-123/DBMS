"""pgvector-backed semantic retrieval for historical complaints.

Requires PostgreSQL pgvector extension and sentence-transformers. Failures are
reported to callers so complaint creation can remain available if vector search
is temporarily unavailable.
"""
from __future__ import annotations

import logging
from functools import lru_cache
from typing import Any

from sqlalchemy import text
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)
EMBEDDING_MODEL_NAME = "sentence-transformers/all-MiniLM-L6-v2"
EMBEDDING_DIMENSIONS = 384


@lru_cache(maxsize=1)
def _model():
    from sentence_transformers import SentenceTransformer
    return SentenceTransformer(EMBEDDING_MODEL_NAME)


def embed_text(value: str) -> list[float]:
    vector = _model().encode(value, normalize_embeddings=True)
    return [float(x) for x in vector.tolist()]


def _vector_literal(vector: list[float]) -> str:
    return "[" + ",".join(f"{v:.8f}" for v in vector) + "]"


def store_complaint_embedding(db: Session, complaint_id: int, description: str) -> None:
    vector = _vector_literal(embed_text(description))
    db.execute(text("""
        INSERT INTO complaint_embeddings (complaint_id, embedding, created_at)
        VALUES (:complaint_id, CAST(:embedding AS vector), CURRENT_TIMESTAMP)
        ON CONFLICT (complaint_id) DO UPDATE
        SET embedding = EXCLUDED.embedding, created_at = CURRENT_TIMESTAMP
    """), {"complaint_id": complaint_id, "embedding": vector})
    db.commit()

def find_similar_complaints(
    db: Session, description: str, exclude_complaint_id: int | None = None, limit: int = 3
) -> list[dict[str, Any]]:
    vector = _vector_literal(embed_text(description))
    limit = max(1, min(int(limit), 10))
    result = db.execute(text("""
        SELECT c.id, c.title, c.description, c.department,
               GREATEST(0, LEAST(1, 1 - (ce.embedding <=> CAST(:embedding AS vector)))) AS similarity
        FROM complaint_embeddings ce
        JOIN complaints c ON c.id = ce.complaint_id
        WHERE (:exclude_id IS NULL OR c.id <> :exclude_id)
        ORDER BY ce.embedding <=> CAST(:embedding AS vector)
        LIMIT :limit
    """), {"embedding": vector, "exclude_id": exclude_complaint_id, "limit": limit})
    return [
        {"id": row.id, "title": row.title, "description": row.description,
         "department": row.department, "similarity": round(float(row.similarity), 4)}
        for row in result.fetchall()
    ]
