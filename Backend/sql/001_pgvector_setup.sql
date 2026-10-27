-- Run against the same PostgreSQL database used by the application.
-- The PostgreSQL server must have the pgvector extension installed.
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE IF NOT EXISTS complaint_embeddings (
    complaint_id INTEGER PRIMARY KEY
        REFERENCES complaints(id) ON DELETE CASCADE,
    embedding vector(384) NOT NULL,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Add after the table has enough rows to benefit from approximate nearest-neighbour search.
-- For a small project dataset, exact cosine-distance ordering is often sufficient.
