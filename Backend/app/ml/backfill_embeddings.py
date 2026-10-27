"""Create/update pgvector embeddings for existing complaints.

Run from Backend/: python -m app.ml.backfill_embeddings
"""
from sqlalchemy import text
from app.database import SessionLocal
from app.ml.vector_store import store_complaint_embedding


def main() -> None:
    db = SessionLocal()
    try:
        rows = db.execute(text("""
            SELECT c.id, c.description
            FROM complaints c
            LEFT JOIN complaint_embeddings ce ON ce.complaint_id = c.id
            WHERE c.description IS NOT NULL AND ce.complaint_id IS NULL
            ORDER BY c.id
        """)).fetchall()
        print(f"Embedding {len(rows)} existing complaints...")
        for index, row in enumerate(rows, start=1):
            store_complaint_embedding(db, row.id, row.description)
            if index % 25 == 0:
                print(f"  Processed {index}/{len(rows)}")
        print("Backfill complete.")
    finally:
        db.close()


if __name__ == "__main__":
    main()
