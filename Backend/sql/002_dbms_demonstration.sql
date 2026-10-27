-- Run after the application tables have been created.
-- Uses PostgreSQL syntax. Demo DDL objects are temporary and DML is rolled back;
-- the complaint_analytics view is intentionally persistent.

-- DDL: CREATE, ALTER, constraints, index, and DROP.
BEGIN;

CREATE TEMP TABLE dbms_ddl_demo (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    label TEXT NOT NULL UNIQUE,
    quantity INTEGER NOT NULL CHECK (quantity >= 0)
);

ALTER TABLE dbms_ddl_demo ADD COLUMN notes TEXT;
CREATE INDEX dbms_ddl_demo_quantity_idx ON dbms_ddl_demo (quantity);

INSERT INTO dbms_ddl_demo (label, quantity, notes)
VALUES ('seed packet', 12, 'Temporary DDL/DML example');

UPDATE dbms_ddl_demo
SET quantity = quantity - 2
WHERE label = 'seed packet';

SELECT id, label, quantity, notes
FROM dbms_ddl_demo
ORDER BY label;

DELETE FROM dbms_ddl_demo
WHERE label = 'seed packet';

DROP INDEX dbms_ddl_demo_quantity_idx;
DROP TABLE dbms_ddl_demo;
COMMIT;

-- DML on the application schema. The inserted complaint, update, and delete
-- are visible as RETURNING rows for demonstration, then the transaction rolls back.
BEGIN;

CREATE TEMP TABLE dbms_demo_complaint_ids (
    complaint_id INTEGER PRIMARY KEY
) ON COMMIT DROP;

WITH inserted AS (
    INSERT INTO complaints (citizen_id, title, description, location, village)
    SELECT id, '[DBMS demonstration]', 'Temporary transaction example',
           'Demo location', village
    FROM users
    WHERE role::text = 'citizen'
    ORDER BY id
    LIMIT 1
    RETURNING id
)
INSERT INTO dbms_demo_complaint_ids (complaint_id)
SELECT id FROM inserted;

UPDATE complaints
SET description = 'Updated inside a transaction that will be rolled back'
WHERE id IN (SELECT complaint_id FROM dbms_demo_complaint_ids)
RETURNING id, title, description;

DELETE FROM complaints
WHERE id IN (SELECT complaint_id FROM dbms_demo_complaint_ids)
RETURNING id, title;

ROLLBACK;

-- JOIN, GROUP BY, HAVING, aggregate functions, and ORDER BY.
SELECT
    c.id,
    c.title,
    u.full_name AS citizen,
    COUNT(cc.id) AS comment_count,
    MAX(cc.created_at) AS latest_comment_at
FROM complaints AS c
JOIN users AS u ON u.id = c.citizen_id
LEFT JOIN complaint_comments AS cc ON cc.complaint_id = c.id
GROUP BY c.id, c.title, u.full_name, c.created_at
HAVING COUNT(cc.id) > 0
ORDER BY c.created_at DESC;

-- Subquery: complaints with more comments than the average commented complaint.
SELECT
    c.id,
    c.title,
    COUNT(cc.id) AS comment_count
FROM complaints AS c
JOIN complaint_comments AS cc ON cc.complaint_id = c.id
GROUP BY c.id, c.title
HAVING COUNT(cc.id) > (
    SELECT AVG(comment_count)
    FROM (
        SELECT COUNT(*) AS comment_count
        FROM complaint_comments
        GROUP BY complaint_id
    ) AS comment_totals
)
ORDER BY comment_count DESC, c.id;

-- Aggregate query by village, including complaints resolved to date.
SELECT
    COALESCE(village, 'Unspecified') AS village,
    COUNT(*) AS complaint_count,
    COUNT(*) FILTER (WHERE status::text = 'resolved') AS resolved_count
FROM complaints
GROUP BY village
HAVING COUNT(*) >= 1
ORDER BY complaint_count DESC, village;

-- Advanced concept: a reusable relational view for complaint analytics.
CREATE OR REPLACE VIEW complaint_analytics AS
SELECT
    c.id AS complaint_id,
    c.title,
    c.department,
    c.status,
    c.village,
    u.full_name AS citizen,
    COUNT(cc.id) AS comment_count,
    c.created_at
FROM complaints AS c
JOIN users AS u ON u.id = c.citizen_id
LEFT JOIN complaint_comments AS cc ON cc.complaint_id = c.id
GROUP BY c.id, c.title, c.department, c.status, c.village, u.full_name, c.created_at;

SELECT complaint_id, title, department, status, village, citizen, comment_count
FROM complaint_analytics
ORDER BY created_at DESC;