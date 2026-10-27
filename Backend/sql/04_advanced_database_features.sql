-- ============================================================================
-- DBMS Level 3 Project: Village Development Platform
-- Script 04: Advanced Database Concepts Implementation & Demonstration
-- Database: PostgreSQL 16 with pgvector extension
-- Demonstrates:
--   1. ACID Transactions (BEGIN, SAVEPOINT, ROLLBACK, COMMIT)
--   2. Relational Database Views
--   3. PL/pgSQL Stored Procedures & Functions
--   4. PL/pgSQL Triggers & Audit Logging
--   5. Advanced Indexing & Vector Similarity Search (HNSW + Cosine Distance)
-- Author: SABVMCRI & Team
-- ============================================================================

-- ============================================================================
-- ADVANCED CONCEPT 1: ACID TRANSACTIONS
-- Demonstrating Atomicity, Consistency, Isolation, and Durability
-- Scenario: Product Reservation with inventory lock and rollback safeguards
-- ============================================================================

-- Transaction Demonstration A: Successful Multi-Table Atomic Operation
BEGIN;

-- 1. Identify product and verify sufficient stock
DO $$
DECLARE
    v_product_id INT;
    v_farmer_id INT;
    v_order_qty INT := 2;
    v_current_stock INT;
BEGIN
    SELECT id, stock INTO v_product_id, v_current_stock
    FROM products
    WHERE name LIKE 'Neem Coated Bio-Pesticide%'
    FOR UPDATE; -- Row-level lock for isolation

    SELECT id INTO v_farmer_id FROM users WHERE role = 'farmer' LIMIT 1;

    IF v_current_stock >= v_order_qty THEN
        -- Step A: Decrement stock
        UPDATE products SET stock = stock - v_order_qty WHERE id = v_product_id;

        -- Step B: Insert product request
        INSERT INTO product_requests (product_id, farmer_id, quantity, status, batch_id)
        VALUES (v_product_id, v_farmer_id, v_order_qty, 'approved', 'BATCH-' || TO_CHAR(NOW(), 'YYYYMMDD-HH24MISS'));

        -- Step C: Insert notification for the shop owner
        INSERT INTO notifications (user_id, message)
        SELECT s.owner_id, 'New product reservation approved: 2 units of Neem Bio-Pesticide.'
        FROM products p JOIN shops s ON s.id = p.shop_id WHERE p.id = v_product_id;
    END IF;
END $$;

COMMIT;


-- Transaction Demonstration B: Error Handling with SAVEPOINT and Partial ROLLBACK
BEGIN;

-- Create temporary record
INSERT INTO complaint_comments (complaint_id, author_id, message)
SELECT c.id, c.citizen_id, 'Preliminary triage note before formal review'
FROM complaints c LIMIT 1;

SAVEPOINT comment_savepoint;

-- Risky tentative change
UPDATE complaints
SET status = 'rejected'
WHERE id = (SELECT id FROM complaints LIMIT 1);

-- We decide to roll back the status change, keeping the comment
ROLLBACK TO SAVEPOINT comment_savepoint;

-- Complete transaction cleanly
COMMIT;


-- ============================================================================
-- ADVANCED CONCEPT 2: RELATIONAL DATABASE VIEWS
-- ============================================================================

-- View 1: Complaint Analytics View
-- Joins complaints, citizens, latest activity, and calculates turnaround duration
CREATE OR REPLACE VIEW vw_complaint_analytics AS
SELECT 
    c.id AS complaint_id,
    c.title,
    c.department,
    c.status,
    c.priority,
    COALESCE(c.village, u.village, 'Unspecified') AS village,
    u.full_name AS citizen_name,
    u.phone AS citizen_phone,
    COUNT(cc.id) AS comment_count,
    c.created_at AS reported_at,
    c.updated_at AS last_updated_at,
    ROUND(EXTRACT(EPOCH FROM (COALESCE(c.updated_at, CURRENT_TIMESTAMP) - c.created_at)) / 86400.0, 1) AS days_elapsed
FROM complaints c
JOIN users u ON u.id = c.citizen_id
LEFT JOIN complaint_comments cc ON cc.complaint_id = c.id
GROUP BY c.id, c.title, c.department, c.status, c.priority, c.village, u.village, u.full_name, u.phone, c.created_at, c.updated_at;


-- View 2: Village Governance Scorecard
-- Aggregates performance metrics across Gram Panchayats
CREATE OR REPLACE VIEW vw_village_governance_scorecard AS
SELECT 
    COALESCE(c.village, 'Central / All') AS village,
    COUNT(DISTINCT c.id) AS total_complaints,
    COUNT(DISTINCT c.id) FILTER (WHERE c.status = 'resolved') AS resolved_complaints,
    COUNT(DISTINCT c.id) FILTER (WHERE c.status IN ('submitted', 'in_progress')) AS pending_complaints,
    ROUND(
        COALESCE(
            (COUNT(DISTINCT c.id) FILTER (WHERE c.status = 'resolved')::numeric / 
             NULLIF(COUNT(DISTINCT c.id), 0)::numeric) * 100.0, 
            0.0
        ), 1
    ) AS resolution_rate_pct,
    COUNT(DISTINCT sa.id) AS scheme_applications_count,
    COUNT(DISTINCT p.id) AS registered_patients_count
FROM complaints c
LEFT JOIN scheme_applications sa ON sa.village = c.village
LEFT JOIN patients p ON p.village = c.village
GROUP BY c.village;


-- View 3: Service Provider Performance Leaderboard
-- Computes live rating and job volume for local providers
CREATE OR REPLACE VIEW vw_provider_leaderboard AS
SELECT 
    sp.id AS provider_id,
    u.full_name AS provider_name,
    u.phone AS contact_number,
    sp.service_type,
    sp.is_available,
    COUNT(DISTINCT sr.id) AS total_requests_received,
    COUNT(DISTINCT sr.id) FILTER (WHERE sr.status = 'completed') AS completed_jobs,
    COUNT(DISTINCT r.id) AS total_reviews,
    COALESCE(ROUND(AVG(r.rating)::numeric, 2), 0.00) AS avg_rating
FROM service_providers sp
JOIN users u ON u.id = sp.user_id
LEFT JOIN service_requests sr ON sr.provider_id = sp.id
LEFT JOIN reviews r ON r.provider_id = sp.id
GROUP BY sp.id, u.full_name, u.phone, sp.service_type, sp.is_available;


-- View 4: Agricultural Inventory Health
-- Categorizes products into stock health tiers
CREATE OR REPLACE VIEW vw_agricultural_inventory_health AS
SELECT 
    p.id AS product_id,
    s.name AS shop_name,
    p.name AS product_name,
    p.category,
    p.price,
    p.stock,
    p.low_stock_threshold,
    p.unit,
    CASE 
        WHEN p.stock = 0 THEN 'OUT_OF_STOCK'
        WHEN p.stock <= p.low_stock_threshold THEN 'LOW_STOCK_WARNING'
        ELSE 'HEALTHY'
    END AS stock_status
FROM products p
JOIN shops s ON s.id = p.shop_id;


-- ============================================================================
-- ADVANCED CONCEPT 3: PL/pgSQL STORED PROCEDURES & FUNCTIONS
-- ============================================================================

-- Procedure 1: sp_resolve_complaint
-- Atomically transitions complaint status, records official notes, adds notification,
-- and creates an audit entry.
CREATE OR REPLACE PROCEDURE sp_resolve_complaint(
    p_complaint_id INT,
    p_official_id INT,
    p_resolution_notes TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_citizen_id INT;
    v_old_status complaintstatus;
    v_complaint_title VARCHAR(200);
BEGIN
    -- Verify complaint exists
    SELECT citizen_id, status, title 
    INTO v_citizen_id, v_old_status, v_complaint_title
    FROM complaints 
    WHERE id = p_complaint_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Complaint ID % not found.', p_complaint_id;
    END IF;

    -- Update complaint status
    UPDATE complaints
    SET status = 'resolved',
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_complaint_id;

    -- Insert official comment with resolution explanation
    INSERT INTO complaint_comments (complaint_id, author_id, message)
    VALUES (p_complaint_id, p_official_id, 'Resolution note: ' || p_resolution_notes);

    -- Insert notification for the citizen
    INSERT INTO notifications (user_id, complaint_id, message)
    VALUES (
        v_citizen_id, 
        p_complaint_id, 
        'Your grievance "' || v_complaint_title || '" has been marked as RESOLVED by the Panchayat.'
    );

    RAISE NOTICE 'Complaint % successfully resolved by official %.', p_complaint_id, p_official_id;
END;
$$;


-- Procedure 2: sp_fulfill_product_order
-- Transactionally fulfills an agricultural product order with stock validation
CREATE OR REPLACE PROCEDURE sp_fulfill_product_order(
    p_farmer_id INT,
    p_product_id INT,
    p_quantity INT,
    OUT p_status_msg TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_current_stock INT;
    v_product_name VARCHAR(150);
    v_shop_owner_id INT;
BEGIN
    IF p_quantity <= 0 THEN
        p_status_msg := 'FAILED: Order quantity must be greater than zero.';
        RETURN;
    END IF;

    -- Lock product row for safe concurrent modification
    SELECT p.name, p.stock, s.owner_id
    INTO v_product_name, v_current_stock, v_shop_owner_id
    FROM products p
    JOIN shops s ON s.id = p.shop_id
    WHERE p.id = p_product_id
    FOR UPDATE;

    IF NOT FOUND THEN
        p_status_msg := 'FAILED: Product not found.';
        RETURN;
    END IF;

    IF v_current_stock < p_quantity THEN
        p_status_msg := 'FAILED: Insufficient stock. Available: ' || v_current_stock;
        RETURN;
    END IF;

    -- Deduct stock
    UPDATE products
    SET stock = stock - p_quantity
    WHERE id = p_product_id;

    -- Create approved request
    INSERT INTO product_requests (product_id, farmer_id, quantity, status, batch_id)
    VALUES (p_product_id, p_farmer_id, p_quantity, 'approved', 'ORD-' || TO_CHAR(NOW(), 'YYYYMMDD-HH24MISS'));

    -- Send notification to farmer
    INSERT INTO notifications (user_id, message)
    VALUES (p_farmer_id, 'Your order for ' || p_quantity || ' units of ' || v_product_name || ' was confirmed.');

    p_status_msg := 'SUCCESS: Order placed for ' || p_quantity || ' units of ' || v_product_name;
END;
$$;


-- Function 1: fn_calculate_provider_score
-- Returns a composite performance score (0 - 100) combining rating and job volume
CREATE OR REPLACE FUNCTION fn_calculate_provider_score(p_provider_id INT)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    v_avg_rating NUMERIC;
    v_completed_jobs INT;
    v_final_score NUMERIC;
BEGIN
    SELECT 
        COALESCE(AVG(r.rating), 0),
        COUNT(DISTINCT sr.id) FILTER (WHERE sr.status = 'completed')
    INTO v_avg_rating, v_completed_jobs
    FROM service_providers sp
    LEFT JOIN reviews r ON r.provider_id = sp.id
    LEFT JOIN service_requests sr ON sr.provider_id = sp.id
    WHERE sp.id = p_provider_id;

    -- Formula: (Avg Rating / 5.0 * 70 points) + (Capped Completed Jobs * 3 points up to 30 points)
    v_final_score := (v_avg_rating / 5.0 * 70.0) + LEAST(v_completed_jobs * 3.0, 30.0);
    RETURN ROUND(v_final_score, 1);
END;
$$;


-- ============================================================================
-- ADVANCED CONCEPT 4: PL/pgSQL TRIGGERS & AUDIT LOGGING
-- ============================================================================

-- Ensure the audit log table exists
CREATE TABLE IF NOT EXISTS complaint_audit_log (
    id SERIAL PRIMARY KEY,
    complaint_id INTEGER NOT NULL REFERENCES complaints(id) ON DELETE CASCADE,
    old_status VARCHAR(50),
    new_status VARCHAR(50) NOT NULL,
    old_priority VARCHAR(50),
    new_priority VARCHAR(50),
    changed_by_user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    changed_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    remarks TEXT
);

-- Trigger 1: Automatic Complaint Status Change Audit
CREATE OR REPLACE FUNCTION fn_trg_complaint_status_audit()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Log only when status or priority changes
    IF (OLD.status IS DISTINCT FROM NEW.status) OR (OLD.priority IS DISTINCT FROM NEW.priority) THEN
        INSERT INTO complaint_audit_log (
            complaint_id,
            old_status,
            new_status,
            old_priority,
            new_priority,
            changed_at,
            remarks
        ) VALUES (
            NEW.id,
            OLD.status,
            NEW.status,
            OLD.priority,
            NEW.priority,
            CURRENT_TIMESTAMP,
            'Status transitioned from ' || COALESCE(OLD.status::text, 'NULL') || ' to ' || NEW.status::text
        );
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_complaint_status_audit ON complaints;
CREATE TRIGGER trg_complaint_status_audit
AFTER UPDATE ON complaints
FOR EACH ROW
EXECUTE FUNCTION fn_trg_complaint_status_audit();


-- Trigger 2: Prevent Negative Inventory Stock at Engine Level
CREATE OR REPLACE FUNCTION fn_trg_prevent_negative_stock()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.stock < 0 THEN
        RAISE EXCEPTION 'Integrity Error: Stock for product "%" cannot be negative (Attempted value: %).', NEW.name, NEW.stock;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_negative_stock ON products;
CREATE TRIGGER trg_prevent_negative_stock
BEFORE INSERT OR UPDATE OF stock ON products
FOR EACH ROW
EXECUTE FUNCTION fn_trg_prevent_negative_stock();


-- Trigger 3: Automatic Notification on New Comment
CREATE OR REPLACE FUNCTION fn_trg_notify_on_comment()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_complaint_citizen_id INT;
    v_complaint_title VARCHAR(200);
BEGIN
    SELECT citizen_id, title INTO v_complaint_citizen_id, v_complaint_title
    FROM complaints WHERE id = NEW.complaint_id;

    -- If comment is posted by someone other than the citizen, notify the citizen
    IF NEW.author_id <> v_complaint_citizen_id THEN
        INSERT INTO notifications (user_id, complaint_id, message)
        VALUES (
            v_complaint_citizen_id,
            NEW.complaint_id,
            'New update on your complaint "' || v_complaint_title || '": ' || SUBSTRING(NEW.message FROM 1 FOR 60) || '...'
        );
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_on_comment ON complaint_comments;
CREATE TRIGGER trg_notify_on_comment
AFTER INSERT ON complaint_comments
FOR EACH ROW
EXECUTE FUNCTION fn_trg_notify_on_comment();


-- ============================================================================
-- ADVANCED CONCEPT 5: ADVANCED INDEXING & VECTOR SIMILARITY SEARCH
-- ============================================================================

-- B-Tree Composite Index for fast filtering on village and complaint status
CREATE INDEX IF NOT EXISTS idx_complaints_village_status ON complaints (village, status);

-- B-Tree Composite Index for fast pricing lookups by product category
CREATE INDEX IF NOT EXISTS idx_products_cat_price ON products (category, price);

-- HNSW Vector Index on pgvector embeddings using Cosine Distance
CREATE INDEX IF NOT EXISTS idx_complaint_embeddings_hnsw 
ON complaint_embeddings 
USING hnsw (embedding vector_cosine_ops);

-- Demonstration Query: Semantic Vector Similarity Search via Cosine Distance (<=>)
-- Finds top 3 historical complaints matching query vector with similarity score
SELECT 
    c.id AS complaint_id,
    c.title,
    c.description,
    c.department,
    c.status,
    ROUND((1 - (ce.embedding <=> (SELECT embedding FROM complaint_embeddings LIMIT 1)))::numeric, 4) AS cosine_similarity
FROM complaint_embeddings ce
JOIN complaints c ON c.id = ce.complaint_id
ORDER BY ce.embedding <=> (SELECT embedding FROM complaint_embeddings LIMIT 1)
LIMIT 3;
