# Viva & Project Demonstration Guide
## DBMS Experiential Learning — Level 3 Project
### Village Development Platform (SQL + Vector Database)

This step-by-step script is prepared for your live evaluation with your faculty evaluator / professor. Follow these stages during your demonstration.

---

## Stage 1: Quick Introduction & Architecture Overview (1-2 Minutes)

### What to say:
> "Good morning / afternoon Professor. Our project is the **Village Development Platform**, addressing rural governance, agricultural logistics, and local service access.
> In accordance with the Level 3 Project requirements, we implemented **Option 2: Hybrid Relational Database (PostgreSQL 16) + Vector Database (pgvector)**.
> 
> Our relational database maintains 18 tables in Third Normal Form (3NF) with strict constraints and triggers, ensuring that business rules like non-negative inventory and rating bounds are enforced at the database engine level.
> 
> For unstructured complaints, we deploy 384-dimensional vector embeddings with HNSW indexing to detect duplicate or semantically identical grievances across the Panchayat."

---

## Stage 2: Database Schema & Live Demonstration (3-4 Minutes)

Open your terminal or `psql` and run the following commands to demonstrate the database components:

### 1. Show all 18 tables and extension:
```bash
psql -U village_user -d village_platform -c "\dx vector"
psql -U village_user -d village_platform -c "\dt"
```
*Evaluator sees:* `vector` extension version and all 18 tables (`complaints`, `complaint_embeddings`, `products`, `reviews`, `complaint_audit_log`, etc.).

### 2. Demonstrate Database Level Constraints:
Run a query attempting to violate stock integrity:
```sql
-- Attempt negative stock (Demonstrates CHECK Constraint & Trigger)
UPDATE products SET stock = -10 WHERE id = 1;
```
*Expected Output:*
```
ERROR: new row for relation "products" violates check constraint "chk_products_stock_non_negative"
```
*What to say:*
> "Notice that the application does not rely solely on frontend or backend Python validation. The PostgreSQL engine actively rejects any invalid data modification."

---

## Stage 3: Advanced Database Features (5 Minutes)

Demonstrate the **five advanced concepts** implemented in `sql/04_advanced_database_features.sql`:

### 1. Advanced Concept 1: Database Views
Run:
```sql
SELECT * FROM vw_complaint_analytics LIMIT 3;
SELECT * FROM vw_village_governance_scorecard;
SELECT * FROM vw_agricultural_inventory_health LIMIT 3;
```
*What to say:*
> "We created 4 persistent relational views. For example, `vw_village_governance_scorecard` dynamically computes grievance resolution percentages and active welfare schemes per village."

### 2. Advanced Concept 2: Stored Procedures & Triggers in Action
Demonstrate resolving a complaint using the stored procedure:
```sql
-- 1. Check existing audit logs
SELECT * FROM complaint_audit_log ORDER BY changed_at DESC LIMIT 1;

-- 2. Execute Stored Procedure
CALL sp_resolve_complaint(1, 9, 'Inspected by electrical lineman and power supply restored.');

-- 3. Verify Trigger fired automatically
SELECT * FROM complaint_audit_log WHERE complaint_id = 1 ORDER BY changed_at DESC LIMIT 1;
```
*What to say:*
> "`sp_resolve_complaint` is an atomic PL/pgSQL stored procedure. When it updates the complaint status, our `trg_complaint_status_audit` trigger fires automatically, inserting an audit entry with the previous status, new status, and timestamp into `complaint_audit_log`."

### 3. Advanced Concept 3: pgvector Semantic Similarity Search
Run:
```sql
SELECT 
    c.id, 
    c.title, 
    c.description, 
    c.department, 
    ROUND((1 - (ce.embedding <=> (SELECT embedding FROM complaint_embeddings LIMIT 1)))::numeric, 4) AS similarity_score
FROM complaint_embeddings ce
JOIN complaints c ON c.id = ce.complaint_id
ORDER BY ce.embedding <=> (SELECT embedding FROM complaint_embeddings LIMIT 1)
LIMIT 3;
```
*What to say:*
> "Here, PostgreSQL's pgvector calculates the cosine distance between the complaint embedding and the historical dataset. The HNSW index accelerates this search, instantly surfacing related complaints."

---

## Stage 4: Complex Queries Demonstration (2-3 Minutes)

Run the complex analytical queries from `sql/03_complex_queries.sql`:

### 1. Correlated Subquery (Products priced above category average):
```sql
SELECT p1.name, p1.category, p1.price,
       (SELECT ROUND(AVG(p2.price)::numeric, 2) FROM products p2 WHERE p2.category = p1.category) AS cat_avg
FROM products p1
WHERE p1.price > (SELECT AVG(p2.price) FROM products p2 WHERE p2.category = p1.category);
```

### 2. Multi-Table Aggregation with GROUP BY, HAVING and FILTER:
```sql
SELECT department, village, COUNT(*) AS total,
       COUNT(*) FILTER (WHERE status = 'resolved') AS resolved,
       ROUND((COUNT(*) FILTER (WHERE status = 'resolved')::numeric / COUNT(*)::numeric) * 100, 1) AS pct_resolved
FROM complaints
GROUP BY department, village
HAVING COUNT(*) >= 1;
```

---

## Stage 5: Automated Test Suite & Code Verification (1 Minute)

Run the automated PyTest suite to prove all requirements pass:
```bash
cd Backend
$env:PYTHONPATH="."
pytest tests/test_dbms_comprehensive.py -v
```
*Expected Output:*
```
10 passed, 251 warnings in 15.85s (100% SUCCESS)
- test_all_database_tables_exist ........................ PASSED
- test_prevent_negative_stock_integrity ................. PASSED
- test_review_rating_check_constraint .................. PASSED
- test_rbac_citizen_forbidden_from_official_dashboard .. PASSED
- test_rbac_official_allowed_access_to_dashboard ....... PASSED
- test_rbac_unauthenticated_request_rejected ........... PASSED
- test_ml_complaint_classifier_predictions ............. PASSED
- test_pgvector_similarity_search ...................... PASSED
- test_stored_procedure_and_status_trigger ............. PASSED
- test_relational_views_queryable ...................... PASSED
```

---

## Stage 6: Running the Web Application Interface

### 1. Start the Backend API (FastAPI):
```bash
cd Backend
uvicorn app.main:app --reload
```
API Documentation will be live at: `http://localhost:8000/docs`

### 2. Start the Frontend (React + Vite):
```bash
cd Frontend
npm run dev
```
Open `http://localhost:5173` in your browser.

Demonstrate:
1. Citizen login & filing a grievance with auto-department classification.
2. Official login & viewing the Panchayat dashboard.
3. Agro-catalog with real-time stock status.
