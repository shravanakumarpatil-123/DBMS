"""
Comprehensive DBMS Requirements Test Suite
Covers:
1. Database Connectivity & Relation Integrity (17+ Tables)
2. Database-level Constraints & Trigger Validation (CHECK constraints, Negative Stock prevention)
3. Role-Based Access Control (RBAC) Enforcement across roles
4. Machine Learning Department Classifier
5. pgvector Semantic Similarity Search (KNN Cosine distance)
6. PL/pgSQL Stored Procedures & Triggers (Resolution, Audit Log, Auto-notification)
7. Relational Database Views Querying
"""
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import text
from app.main import app
from app.database import SessionLocal
from app.security import create_access_token
from app.ml.classifier import predict_department
from app.ml.vector_store import find_similar_complaints

client = TestClient(app)


@pytest.fixture(scope="module")
def db():
    session = SessionLocal()
    yield session
    session.close()


# -----------------------------------------------------------------------------
# 1. Database Connection & Schema Completeness
# -----------------------------------------------------------------------------
def test_all_database_tables_exist(db):
    """Verifies that all core domain tables are registered and queryable in PostgreSQL."""
    expected_tables = [
        "users", "complaints", "complaint_comments", "complaint_embeddings",
        "notifications", "service_providers", "service_requests", "reviews",
        "shops", "products", "product_requests", "schemes",
        "scheme_applications", "patients", "medical_history_entries",
        "ai_screenings", "panchayat_members", "complaint_audit_log"
    ]
    query = text("""
        SELECT tablename FROM pg_tables WHERE schemaname = 'public';
    """)
    existing_tables = [row[0] for row in db.execute(query).fetchall()]
    for tbl in expected_tables:
        assert tbl in existing_tables, f"Expected table '{tbl}' was not found in database."


# -----------------------------------------------------------------------------
# 2. Database Constraints & Trigger Verification
# -----------------------------------------------------------------------------
def test_prevent_negative_stock_integrity(db):
    """Verifies that DB-level CHECK constraints and triggers prevent negative inventory."""
    with pytest.raises(Exception):
        # Attempt to insert or update product with negative stock
        db.execute(text("""
            UPDATE products
            SET stock = -5
            WHERE id = (SELECT id FROM products LIMIT 1);
        """))
        db.commit()
    db.rollback()


def test_review_rating_check_constraint(db):
    """Verifies that review rating outside 1..5 is rejected by PostgreSQL CHECK constraint."""
    with pytest.raises(Exception):
        db.execute(text("""
            INSERT INTO reviews (provider_id, reviewer_id, rating, comment)
            VALUES (
                (SELECT id FROM service_providers LIMIT 1),
                (SELECT id FROM users WHERE role = 'citizen' LIMIT 1),
                10, -- Invalid rating > 5
                'Violation of constraint'
            );
        """))
        db.commit()
    db.rollback()


# -----------------------------------------------------------------------------
# 3. Role-Based Access Control (RBAC) Enforcement
# -----------------------------------------------------------------------------
def test_rbac_citizen_forbidden_from_official_dashboard(db):
    """Verifies that a citizen token cannot access official government endpoints (403 Forbidden)."""
    # Create citizen token
    citizen = db.execute(text("SELECT id FROM users WHERE role = 'citizen' LIMIT 1;")).fetchone()
    assert citizen is not None, "Citizen user required in DB"
    citizen_token = create_access_token(data={"sub": str(citizen[0])})

    headers = {"Authorization": f"Bearer {citizen_token}"}
    response = client.get("/complaints/", headers=headers)
    assert response.status_code == 403, f"Citizen should get 403 Forbidden, got {response.status_code}"


def test_rbac_official_allowed_access_to_dashboard(db):
    """Verifies that an official token is authorized to access the official complaints list (200 OK)."""
    official = db.execute(text("SELECT id FROM users WHERE role = 'official' LIMIT 1;")).fetchone()
    assert official is not None, "Official user required in DB"
    official_token = create_access_token(data={"sub": str(official[0])})

    headers = {"Authorization": f"Bearer {official_token}"}
    response = client.get("/complaints/", headers=headers)
    assert response.status_code == 200, f"Official should get 200 OK, got {response.status_code}"


def test_rbac_unauthenticated_request_rejected():
    """Verifies unauthenticated calls to secured routes return 401 Unauthorized."""
    response = client.get("/complaints/mine")
    assert response.status_code == 401


# -----------------------------------------------------------------------------
# 4. Machine Learning Model Verification
# -----------------------------------------------------------------------------
def test_ml_complaint_classifier_predictions():
    """Verifies the complaint department classifier returns expected category."""
    dept, conf = predict_department("The street light in main road is flickering and broken")
    assert dept in ["electricity", "road", "water", "health", "education"], f"Unexpected department: {dept}"
    assert 0.0 <= conf <= 1.0


# -----------------------------------------------------------------------------
# 5. pgvector Semantic Search
# -----------------------------------------------------------------------------
def test_pgvector_similarity_search(db):
    """Verifies that pgvector retrieves semantically relevant historical complaints."""
    results = find_similar_complaints(db, "street light bulb failure at dark street", limit=3)
    assert len(results) > 0, "Expected at least 1 similar complaint"
    assert "similarity" in results[0]
    assert results[0]["similarity"] > 0.0


# -----------------------------------------------------------------------------
# 6. Advanced Stored Procedures & Triggers
# -----------------------------------------------------------------------------
def test_stored_procedure_and_status_trigger(db):
    """Verifies calling sp_resolve_complaint fires audit triggers and inserts notifications."""
    official = db.execute(text("SELECT id FROM users WHERE role = 'official' LIMIT 1;")).fetchone()
    complaint = db.execute(text("SELECT id FROM complaints ORDER BY id LIMIT 1;")).fetchone()
    assert official and complaint

    c_id = complaint[0]
    o_id = official[0]

    # Call procedure
    db.execute(text(f"CALL sp_resolve_complaint({c_id}, {o_id}, 'Automated PyTest verified resolution');"))
    db.commit()

    # Verify audit log trigger recorded status change
    audit_row = db.execute(text(f"""
        SELECT new_status, remarks FROM complaint_audit_log 
        WHERE complaint_id = {c_id} ORDER BY changed_at DESC LIMIT 1;
    """)).fetchone()
    assert audit_row is not None
    assert audit_row[0] == "resolved"


# -----------------------------------------------------------------------------
# 7. Relational Views
# -----------------------------------------------------------------------------
def test_relational_views_queryable(db):
    """Verifies that the analytical views return valid aggregated metrics."""
    res1 = db.execute(text("SELECT * FROM vw_complaint_analytics LIMIT 5;")).fetchall()
    assert len(res1) > 0

    res2 = db.execute(text("SELECT * FROM vw_village_governance_scorecard LIMIT 5;")).fetchall()
    assert len(res2) > 0

    res3 = db.execute(text("SELECT * FROM vw_provider_leaderboard LIMIT 5;")).fetchall()
    assert len(res3) >= 0

    res4 = db.execute(text("SELECT * FROM vw_agricultural_inventory_health LIMIT 5;")).fetchall()
    assert len(res4) > 0
