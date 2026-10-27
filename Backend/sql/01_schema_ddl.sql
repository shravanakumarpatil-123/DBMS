-- ============================================================================
-- DBMS Level 3 Project: Village Development Platform
-- Script 01: Complete Relational Schema & DDL Statements
-- Database: PostgreSQL 16 with pgvector extension
-- Author: SABVMCRI & Team
-- ============================================================================

-- 1. Enable Vector Extension (Mandatory for Level 3 Vector Database Component)
CREATE EXTENSION IF NOT EXISTS vector;

-- 2. Custom Enumeration Types
DO $$ BEGIN
    CREATE TYPE userrole AS ENUM (
        'citizen', 'official', 'provider', 'farmer', 'shop_owner', 'asha_worker'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE complaintstatus AS ENUM (
        'submitted', 'in_progress', 'resolved', 'rejected'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE complaintpriority AS ENUM (
        'low', 'medium', 'high', 'urgent'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE servicerequeststatus AS ENUM (
        'pending', 'accepted', 'completed', 'cancelled'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE productrequeststatus AS ENUM (
        'pending', 'approved', 'rejected'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE schemeapplicationstatus AS ENUM (
        'pending', 'approved', 'rejected'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE patientgender AS ENUM (
        'male', 'female', 'other'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- ============================================================================
-- 3. Core Tables DDL with Constraints (PK, FK, UNIQUE, NOT NULL, CHECK)
-- ============================================================================

-- Table 1: Users
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    full_name VARCHAR(150) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    phone VARCHAR(20) UNIQUE,
    hashed_password VARCHAR(255) NOT NULL,
    role userrole NOT NULL DEFAULT 'citizen',
    village VARCHAR(100),
    asha_id VARCHAR(50) UNIQUE,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_users_email CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    CONSTRAINT chk_users_name_not_empty CHECK (LENGTH(TRIM(full_name)) > 0)
);

-- Table 2: Complaints
CREATE TABLE IF NOT EXISTS complaints (
    id SERIAL PRIMARY KEY,
    citizen_id INTEGER NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    department VARCHAR(100),
    status complaintstatus NOT NULL DEFAULT 'submitted',
    priority complaintpriority NOT NULL DEFAULT 'medium',
    location VARCHAR(255),
    village VARCHAR(100),
    photo_path VARCHAR(255),
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_complaint_title_length CHECK (LENGTH(TRIM(title)) >= 3)
);

-- Table 3: Complaint Comments
CREATE TABLE IF NOT EXISTS complaint_comments (
    id SERIAL PRIMARY KEY,
    complaint_id INTEGER NOT NULL REFERENCES complaints(id) ON DELETE CASCADE,
    author_id INTEGER NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    message TEXT NOT NULL,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_comment_message_not_empty CHECK (LENGTH(TRIM(message)) > 0)
);

-- Table 4: Complaint Vector Embeddings (Vector Store)
CREATE TABLE IF NOT EXISTS complaint_embeddings (
    complaint_id INTEGER PRIMARY KEY REFERENCES complaints(id) ON DELETE CASCADE,
    embedding vector(384) NOT NULL,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Table 5: Notifications
CREATE TABLE IF NOT EXISTS notifications (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    complaint_id INTEGER REFERENCES complaints(id) ON DELETE SET NULL,
    message TEXT NOT NULL,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Table 6: Service Providers
CREATE TABLE IF NOT EXISTS service_providers (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    service_type VARCHAR(100) NOT NULL,
    description TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    is_available BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT chk_provider_service_type CHECK (LENGTH(TRIM(service_type)) > 0)
);

-- Table 7: Service Requests
CREATE TABLE IF NOT EXISTS service_requests (
    id SERIAL PRIMARY KEY,
    provider_id INTEGER NOT NULL REFERENCES service_providers(id) ON DELETE RESTRICT,
    requester_id INTEGER NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    description TEXT,
    status servicerequeststatus NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Table 8: Service Reviews
CREATE TABLE IF NOT EXISTS reviews (
    id SERIAL PRIMARY KEY,
    provider_id INTEGER NOT NULL REFERENCES service_providers(id) ON DELETE CASCADE,
    reviewer_id INTEGER NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    rating INTEGER NOT NULL,
    comment TEXT,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_reviews_rating_range CHECK (rating >= 1 AND rating <= 5)
);

-- Table 9: Agricultural Shops
CREATE TABLE IF NOT EXISTS shops (
    id SERIAL PRIMARY KEY,
    owner_id INTEGER NOT NULL UNIQUE REFERENCES users(id) ON DELETE RESTRICT,
    name VARCHAR(150) NOT NULL,
    location VARCHAR(255),
    CONSTRAINT chk_shop_name_not_empty CHECK (LENGTH(TRIM(name)) > 0)
);

-- Table 10: Agricultural Products
CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    shop_id INTEGER NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    name VARCHAR(150) NOT NULL,
    category VARCHAR(100) DEFAULT 'Other agricultural input',
    price DOUBLE PRECISION NOT NULL,
    stock INTEGER NOT NULL DEFAULT 0,
    low_stock_threshold INTEGER DEFAULT 5,
    CONSTRAINT chk_products_price_positive CHECK (price >= 0.0),
    CONSTRAINT chk_products_stock_non_negative CHECK (stock >= 0),
    CONSTRAINT chk_products_threshold_positive CHECK (low_stock_threshold >= 0)
);

-- Table 11: Product Requests / Reservations
CREATE TABLE IF NOT EXISTS product_requests (
    id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    farmer_id INTEGER NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    quantity INTEGER NOT NULL,
    status productrequeststatus NOT NULL DEFAULT 'pending',
    batch_id VARCHAR(100),
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_product_request_quantity_positive CHECK (quantity > 0)
);

-- Table 12: Government Schemes
CREATE TABLE IF NOT EXISTS schemes (
    id SERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    eligibility TEXT,
    department VARCHAR(100),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_by INTEGER NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Table 13: Scheme Applications
CREATE TABLE IF NOT EXISTS scheme_applications (
    id SERIAL PRIMARY KEY,
    scheme_id INTEGER NOT NULL REFERENCES schemes(id) ON DELETE CASCADE,
    citizen_id INTEGER NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    note TEXT,
    status schemeapplicationstatus NOT NULL DEFAULT 'pending',
    village VARCHAR(100),
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Table 14: Patients (Healthcare Module - AppAyu)
CREATE TABLE IF NOT EXISTS patients (
    id SERIAL PRIMARY KEY,
    asha_worker_id INTEGER NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    full_name VARCHAR(150) NOT NULL,
    age INTEGER,
    gender patientgender,
    phone VARCHAR(20),
    village VARCHAR(100),
    address VARCHAR(255),
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_patient_age_valid CHECK (age IS NULL OR (age >= 0 AND age <= 130))
);

-- Table 15: Medical History Entries
CREATE TABLE IF NOT EXISTS medical_history_entries (
    id SERIAL PRIMARY KEY,
    patient_id INTEGER NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    recorded_by_id INTEGER NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    condition VARCHAR(200) NOT NULL,
    notes TEXT,
    visit_date TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Table 16: AI Screenings
CREATE TABLE IF NOT EXISTS ai_screenings (
    id SERIAL PRIMARY KEY,
    patient_id INTEGER NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    asha_worker_id INTEGER NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    screening_type VARCHAR(50) NOT NULL DEFAULT 'skin',
    image_path VARCHAR(255) NOT NULL,
    model_version VARCHAR(50),
    prediction VARCHAR(100),
    confidence DOUBLE PRECISION,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_screening_confidence CHECK (confidence IS NULL OR (confidence >= 0.0 AND confidence <= 1.0))
);

-- Table 17: Panchayat Members
CREATE TABLE IF NOT EXISTS panchayat_members (
    id SERIAL PRIMARY KEY,
    village VARCHAR(100) NOT NULL,
    name VARCHAR(150) NOT NULL,
    position VARCHAR(100),
    phone VARCHAR(20),
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Table 18: Complaint Audit Log (For Advanced Concept: Triggers & Auditability)
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

-- ============================================================================
-- 4. DDL Demonstration: ALTER TABLE and DROP TABLE operations
-- ============================================================================

-- A. Demonstrate ALTER TABLE: Add column, Add check constraint, Create index
ALTER TABLE products ADD COLUMN IF NOT EXISTS unit VARCHAR(20) DEFAULT 'kg';

-- Add check constraints to existing tables safely
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_products_price_positive') THEN
        ALTER TABLE products ADD CONSTRAINT chk_products_price_positive CHECK (price >= 0.0);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_products_stock_non_negative') THEN
        ALTER TABLE products ADD CONSTRAINT chk_products_stock_non_negative CHECK (stock >= 0);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_reviews_rating_range') THEN
        ALTER TABLE reviews ADD CONSTRAINT chk_reviews_rating_range CHECK (rating >= 1 AND rating <= 5);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_patient_age_valid') THEN
        ALTER TABLE patients ADD CONSTRAINT chk_patient_age_valid CHECK (age IS NULL OR (age >= 0 AND age <= 130));
    END IF;
END $$;

-- B. Demonstrate CREATE, ALTER, and DROP on a demo sandbox table
CREATE TABLE IF NOT EXISTS ddl_demo_staging (
    staging_id SERIAL PRIMARY KEY,
    batch_name VARCHAR(100) NOT NULL,
    record_count INT DEFAULT 0
);

ALTER TABLE ddl_demo_staging ADD COLUMN processed_flag BOOLEAN DEFAULT FALSE;
ALTER TABLE ddl_demo_staging ADD CONSTRAINT chk_record_count CHECK (record_count >= 0);

-- Demonstration DROP operation
DROP TABLE IF EXISTS ddl_demo_staging;

-- ============================================================================
-- 5. Performance Indexing Statements (B-Tree + HNSW Vector Index)
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_complaints_village_status ON complaints (village, status);
CREATE INDEX IF NOT EXISTS idx_complaints_citizen ON complaints (citizen_id);
CREATE INDEX IF NOT EXISTS idx_complaints_created ON complaints (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_products_shop_category ON products (shop_id, category);
CREATE INDEX IF NOT EXISTS idx_products_price ON products (price);
CREATE INDEX IF NOT EXISTS idx_reviews_provider ON reviews (provider_id);
CREATE INDEX IF NOT EXISTS idx_service_requests_provider ON service_requests (provider_id, status);
CREATE INDEX IF NOT EXISTS idx_scheme_applications_citizen ON scheme_applications (citizen_id, status);
CREATE INDEX IF NOT EXISTS idx_patients_village ON patients (village);

-- pgvector HNSW Approximate Nearest Neighbour Index for semantic search
CREATE INDEX IF NOT EXISTS idx_complaint_embeddings_hnsw 
ON complaint_embeddings 
USING hnsw (embedding vector_cosine_ops);
