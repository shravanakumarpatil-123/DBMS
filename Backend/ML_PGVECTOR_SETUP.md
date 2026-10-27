# Complaint ML classifier + pgvector setup

This adds a local TF-IDF complaint department classifier and optional semantic retrieval while preserving the existing API and React UI.

## 1. Install Python dependencies

From `Backend/` with your virtual environment activated:

```bash
pip install -r requirements.txt
```

The first embedding request downloads `sentence-transformers/all-MiniLM-L6-v2` (384 dimensions). Internet access is needed for that initial download unless the model is already cached.

## 2. Configure PostgreSQL

The PostgreSQL server must have pgvector installed. Connect to the same database as the app and run `sql/001_pgvector_setup.sql` from this folder, for example:

```bash
psql "$DATABASE_URL" -f sql/001_pgvector_setup.sql
```

If your shell does not have `DATABASE_URL`, use your configured connection string with psql. Do not commit `.env` or credentials.

## 3. Train the classifier

From `Backend/`:

```bash
python -m app.ml.train_complaint_classifier
```

The script writes `app/ml/model_complaint.joblib`, which is loaded by the active router through `Backend/ml/classifier.py`. Training data is `app/ml/Data/complaints_sample.csv`; add correctly labelled, representative examples to improve generalization. The small bundled dataset is for demonstration and is not sufficient evidence of production accuracy.

## 4. Backfill historical complaints

```bash
python -m app.ml.backfill_embeddings
```

This embeds historical complaints not yet in `complaint_embeddings`. New complaint embeddings are saved automatically when pgvector and the embedding model are available. If vector storage is unavailable, complaint creation still succeeds and logs a warning.

## 5. Similarity endpoint

After creating a complaint, call `GET /complaints/{complaint_id}/similar` with the same authentication as other complaint endpoints. It returns up to three similar historical complaints. The endpoint respects the existing complaint access rule (owner or official).

## Design notes

- The classifier predicts the department; pgvector retrieves similar historical complaints. Similarity does not silently override the classifier.
- Existing complaint table and response schema remain unchanged.
- `complaint_embeddings.complaint_id` references `complaints.id` and cascades on deletion.
- If your PostgreSQL hosting provider does not support pgvector, install/enable the extension or use a supported PostgreSQL instance.
