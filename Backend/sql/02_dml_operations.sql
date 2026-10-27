-- ============================================================================
-- DBMS Level 3 Project: Village Development Platform
-- Script 02: Meaningful Database Operations using DML (INSERT, UPDATE, DELETE, SELECT)
-- Database: PostgreSQL 16
-- Author: SABVMCRI & Team
-- ============================================================================

-- ============================================================================
-- 1. INSERT Operations: Populating Domain Data
-- ============================================================================

-- Insert sample users if not already present
INSERT INTO users (full_name, email, phone, hashed_password, role, village)
VALUES
    ('Ramesh Kumar', 'ramesh.farmer@example.com', '9876543210', '$2b$12$eX4mPL3h45h3dp455w0rdH45hV4lu3', 'farmer', 'Shivapura'),
    ('Anand Rao', 'anand.panchayat@example.com', '9876543211', '$2b$12$eX4mPL3h45h3dp455w0rdH45hV4lu3', 'official', 'Shivapura'),
    ('Suresh Electrician', 'suresh.services@example.com', '9876543212', '$2b$12$eX4mPL3h45h3dp455w0rdH45hV4lu3', 'provider', 'Shivapura'),
    ('Kisan Agro Store Owner', 'kisan.agro@example.com', '9876543213', '$2b$12$eX4mPL3h45h3dp455w0rdH45hV4lu3', 'shop_owner', 'Shivapura')
ON CONFLICT (email) DO NOTHING;

-- Insert sample shop
INSERT INTO shops (owner_id, name, location)
SELECT id, 'Kisan Seva Kendra', 'Shivapura Main Bus Stand'
FROM users WHERE email = 'kisan.agro@example.com'
ON CONFLICT (owner_id) DO NOTHING;

-- Multi-row INSERT: Agricultural Products
INSERT INTO products (shop_id, name, category, price, stock, low_stock_threshold, unit)
SELECT s.id, p.name, p.category, p.price, p.stock, p.low_stock_threshold, p.unit
FROM shops s
CROSS JOIN (
    VALUES
        ('Urea Fertilizer (50kg)', 'Fertilizers', 266.50, 45, 10, 'bag'),
        ('DAP Fertilizer (50kg)', 'Fertilizers', 1350.00, 18, 5, 'bag'),
        ('Neem Coated Bio-Pesticide (1L)', 'Pesticides', 420.00, 25, 5, 'bottle'),
        ('Hybrid Tomato Seeds (100g)', 'Seeds', 180.00, 8, 5, 'packet'),
        ('Organic Vermicompost (25kg)', 'Organic Inputs', 220.00, 3, 5, 'bag'),
        ('Drip Irrigation Dripper Nozzles (Pack 50)', 'Equipment', 350.00, 30, 10, 'pack')
) AS p(name, category, price, stock, low_stock_threshold, unit)
WHERE s.name = 'Kisan Seva Kendra'
ON CONFLICT DO NOTHING;

-- Insert Service Provider Profile
INSERT INTO service_providers (user_id, service_type, description, latitude, longitude, is_available)
SELECT u.id, 'Electrician & Pump Motor Specialist', '10+ years experience in motor rewinding and wiring', 15.3647, 75.1240, TRUE
FROM users u WHERE u.email = 'suresh.services@example.com'
ON CONFLICT (user_id) DO NOTHING;

-- Insert Government Scheme
INSERT INTO schemes (title, description, eligibility, department, is_active, created_by)
SELECT 
    'Pradhan Mantri Krishi Sinchayee Yojana (Micro-Irrigation Subsidy)',
    'Subsidies up to 55% for small/marginal farmers for installing drip/sprinkler systems.',
    'Small and marginal farmers holding minimum 1 acre agricultural land.',
    'Agriculture',
    TRUE,
    u.id
FROM users u WHERE u.role = 'official' LIMIT 1
ON CONFLICT DO NOTHING;

-- Insert DDL/DML Demo Complaints
INSERT INTO complaints (citizen_id, title, description, department, status, priority, village, location)
SELECT 
    u.id,
    'Broken Borewell Pipeline near Market',
    'Main water supply pipe burst leaking clean water for 3 days continuously',
    'Water',
    'submitted',
    'urgent',
    COALESCE(u.village, 'Shivapura'),
    'Main Bazaar Road, Shivapura'
FROM users u WHERE u.role = 'citizen' LIMIT 1;

-- ============================================================================
-- 2. UPDATE Operations: Demonstrating Data Modifications
-- ============================================================================

-- A. Update single record by ID with status transition
UPDATE complaints
SET status = 'in_progress',
    priority = 'urgent',
    updated_at = CURRENT_TIMESTAMP
WHERE title = 'Broken Borewell Pipeline near Market';

-- B. Arithmetic UPDATE: Stock deduction upon purchase/allocation
UPDATE products
SET stock = stock - 2
WHERE name LIKE 'Neem Coated Bio-Pesticide%' AND stock >= 2;

-- C. Conditional UPDATE with CASE expression: Adjust priority based on age of complaint
UPDATE complaints
SET priority = CASE 
    WHEN created_at < NOW() - INTERVAL '7 days' AND status = 'submitted' THEN 'urgent'
    WHEN created_at < NOW() - INTERVAL '3 days' AND status = 'submitted' THEN 'high'
    ELSE priority
END
WHERE status IN ('submitted', 'in_progress');

-- D. Mark notifications as read for a user
UPDATE notifications
SET is_read = TRUE
WHERE is_read = FALSE AND user_id IN (
    SELECT id FROM users WHERE role = 'citizen'
);

-- ============================================================================
-- 3. SELECT Operations: Basic and Filtered Queries
-- ============================================================================

-- A. Projection and filtering with comparison operators
SELECT id, title, department, status, priority, village, created_at
FROM complaints
WHERE status <> 'resolved' AND priority IN ('high', 'urgent')
ORDER BY created_at DESC;

-- B. Pattern matching with ILIKE
SELECT id, name, category, price, stock, unit
FROM products
WHERE name ILIKE '%fertilizer%' OR category ILIKE '%fertilizer%'
ORDER BY price ASC;

-- C. Availability check for service providers
SELECT sp.id, u.full_name, sp.service_type, sp.is_available
FROM service_providers sp
JOIN users u ON u.id = sp.user_id
WHERE sp.is_available = TRUE;

-- ============================================================================
-- 4. DELETE Operations: Safe and Cascading Deletions
-- ============================================================================

-- Demonstrate transactional DELETE with rollback safeguard
BEGIN;

-- Insert a test comment to demonstrate deletion
INSERT INTO complaint_comments (complaint_id, author_id, message)
SELECT c.id, c.citizen_id, 'Draft comment to test deletion'
FROM complaints c LIMIT 1;

-- Delete the specific comment
DELETE FROM complaint_comments
WHERE message = 'Draft comment to test deletion';

-- Verify deletion within transaction
SELECT COUNT(*) AS remaining_matching_comments
FROM complaint_comments
WHERE message = 'Draft comment to test deletion';

COMMIT;
