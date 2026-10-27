# Village Development Platform

### DBMS Experiential Learning — Level 3 Project (PES University)
**Paradigm:** Hybrid Multi-Paradigm Database (Relational PostgreSQL 16 + Vector Database pgvector)  
**Backend:** FastAPI, SQLAlchemy 2.0, Uvicorn, Scikit-Learn, PyTorch, Sentence-Transformers  
**Frontend:** React 18, Vite, React Router 6  

---

## 🌟 Quick Links to Submission Deliverables
- 📄 **Complete Level 3 DBMS Project Report:** [`docs/DBMS_LEVEL3_PROJECT_REPORT.md`](docs/DBMS_LEVEL3_PROJECT_REPORT.md)
- 🎯 **Viva & Project Demonstration Script:** [`docs/VIVA_DEMONSTRATION_GUIDE.md`](docs/VIVA_DEMONSTRATION_GUIDE.md)
- 🧪 **Comprehensive PyTest Test Suite:** [`Backend/tests/test_dbms_comprehensive.py`](Backend/tests/test_dbms_comprehensive.py) (10/10 Passed)
- 🗄️ **Modular SQL Scripts:**
  - [`Backend/sql/01_schema_ddl.sql`](Backend/sql/01_schema_ddl.sql) — Full Relational DDL, Constraints (PK, FK, UNIQUE, CHECK), Types, and Indexes
  - [`Backend/sql/02_dml_operations.sql`](Backend/sql/02_dml_operations.sql) — Meaningful DML (INSERT, UPDATE, DELETE, SELECT)
  - [`Backend/sql/03_complex_queries.sql`](Backend/sql/03_complex_queries.sql) — Multi-table JOINs, GROUP BY, HAVING, ORDER BY, Aggregates, Correlated & Window Subqueries
  - [`Backend/sql/04_advanced_database_features.sql`](Backend/sql/04_advanced_database_features.sql) — ACID Transactions, Views, Stored Procedures, Triggers, and HNSW Vector Search

---

## 🚀 Setup & Execution Guide

### 1. Database Configuration (PostgreSQL 16 with pgvector)
Ensure PostgreSQL is running locally and credentials match `Backend/.env`:
```ini
DATABASE_URL=postgresql://village_user:Shanu%40123@localhost:5432/village_platform
```

Run the SQL scripts to initialize schema, test data, and advanced features:
```bash
# Execute DDL schema, types, constraints, and indexes
psql -U village_user -d village_platform -f Backend/sql/01_schema_ddl.sql

# Populate sample data and execute DML operations
psql -U village_user -d village_platform -f Backend/sql/02_dml_operations.sql

# Execute complex analytical queries
psql -U village_user -d village_platform -f Backend/sql/03_complex_queries.sql

# Initialize ACID transactions, views, triggers, and stored procedures
psql -U village_user -d village_platform -f Backend/sql/04_advanced_database_features.sql
```

### 2. Backend API Setup (FastAPI)
From the `Backend/` directory:
```bash
# Activate your environment and run tests
$env:PYTHONPATH="."
pytest tests/test_dbms_comprehensive.py -v

# Start the API server
uvicorn app.main:app --reload
```
Interactive Swagger API documentation will be available at: `http://localhost:8000/docs`

### 3. Frontend Web Interface Setup (React / Vite)
From the `Frontend/` directory:
```bash
npm install
npm run dev
```
Open `http://localhost:5173` in your browser.

---

## 🏗️ Architecture & Database Paradigm

```
                    ┌──────────────────────────────────────────────┐
                    │          VILLAGE DEVELOPMENT PLATFORM        │
                    └──────────────────────┬───────────────────────┘
                                           │
                 ┌─────────────────────────┴─────────────────────────┐
                 │                                                   │
                 ▼                                                   ▼
   ┌───────────────────────────┐                       ┌───────────────────────────┐
   │    RELATIONAL DATABASE    │                       │      VECTOR DATABASE      │
   │      (PostgreSQL 16)      │                       │     (pgvector Extension)  │
   ├───────────────────────────┤                       ├───────────────────────────┤
   │ • 18 Relational Tables    │                       │ • 384-dimensional Vectors │
   │ • 3NF Normalization       │                       │ • all-MiniLM-L6-v2 Model  │
   │ • CHECK Constraints       │                       │ • Cosine Distance (<=>)   │
   │ • PL/pgSQL Triggers       │                       │ • HNSW Vector Index       │
   │ • Stored Procedures       │                       │ • Semantic Duplicate      │
   │ • Analytical Views        │                       │   Grievance Discovery     │
   └───────────────────────────┘                       └───────────────────────────┘
```

---

## 📊 Summary of Advanced Database Features Implemented

1. **ACID Transactions:**
   - Multi-table atomic reservations for agricultural inventory with row-level locks (`SELECT ... FOR UPDATE`), `SAVEPOINT`, and partial `ROLLBACK`.
2. **Relational Database Views:**
   - `vw_complaint_analytics`: Turnaround SLA tracking and citizen activity.
   - `vw_village_governance_scorecard`: Village-level grievance resolution rates and welfare enrollment.
   - `vw_provider_leaderboard`: Real-time rating and service request completion metrics.
   - `vw_agricultural_inventory_health`: Categorization into `'OUT_OF_STOCK'`, `'LOW_STOCK_WARNING'`, and `'HEALTHY'`.
3. **PL/pgSQL Stored Procedures & Functions:**
   - `sp_resolve_complaint`: Atomic grievance resolution, official commentary, citizen notification, and audit entry.
   - `sp_fulfill_product_order`: Atomic inventory verification and order allocation.
   - `fn_calculate_provider_score`: Composite provider quality score (0-100).
4. **PL/pgSQL Database Triggers:**
   - `trg_complaint_status_audit`: Automatically audits every status and priority transition to `complaint_audit_log`.
   - `trg_prevent_negative_stock`: Enforces non-negative inventory at the database engine level.
   - `trg_notify_on_comment`: Auto-dispatches notifications when officials or citizens post comments.
5. **Advanced Indexing & Vector Similarity Search:**
   - Composite B-Tree indexes on `(village, status)` and `(category, price)`.
   - HNSW index on `complaint_embeddings (embedding vector_cosine_ops)` for sub-millisecond similarity queries.
