-- ============================================================================
-- DBMS Level 3 Project: Village Development Platform
-- Script 03: Complex Analytical Queries (JOINs, GROUP BY, HAVING, ORDER BY, Aggregates, Subqueries)
-- Database: PostgreSQL 16
-- Author: SABVMCRI & Team
-- ============================================================================

-- ============================================================================
-- Query 1: Multi-Table INNER JOIN with Aggregates & ORDER BY
-- Description: Retrieves detailed grievance reports joining complaints with citizen 
-- profiles and comment interactions, ordered by latest activity.
-- ============================================================================
SELECT 
    c.id AS complaint_id,
    c.title AS complaint_title,
    c.department,
    c.status,
    c.priority,
    COALESCE(c.village, u.village, 'Unassigned') AS village,
    u.full_name AS citizen_name,
    u.phone AS citizen_phone,
    COUNT(cc.id) AS total_comments,
    MAX(cc.created_at) AS latest_comment_at,
    c.created_at AS filed_date
FROM complaints c
JOIN users u ON u.id = c.citizen_id
LEFT JOIN complaint_comments cc ON cc.complaint_id = c.id
GROUP BY c.id, c.title, c.department, c.status, c.priority, c.village, u.village, u.full_name, u.phone, c.created_at
ORDER BY c.created_at DESC, total_comments DESC;


-- ============================================================================
-- Query 2: Multi-Table LEFT JOIN with Aggregation & NULL Handling
-- Description: Evaluates local service providers, linking user details, count of
-- service requests received, accepted, and average customer star rating.
-- ============================================================================
SELECT 
    sp.id AS provider_id,
    u.full_name AS provider_name,
    sp.service_type,
    sp.is_available,
    COUNT(DISTINCT sr.id) AS total_requests,
    COUNT(DISTINCT sr.id) FILTER (WHERE sr.status = 'completed') AS completed_jobs,
    COUNT(DISTINCT r.id) AS total_reviews,
    COALESCE(ROUND(AVG(r.rating)::numeric, 2), 0.00) AS average_rating,
    CASE 
        WHEN AVG(r.rating) >= 4.5 THEN 'Exceptional (Tier 1)'
        WHEN AVG(r.rating) >= 3.5 THEN 'Reliable (Tier 2)'
        WHEN COUNT(r.id) = 0 THEN 'New Provider'
        ELSE 'Needs Improvement'
    END AS reputation_tier
FROM service_providers sp
JOIN users u ON u.id = sp.user_id
LEFT JOIN service_requests sr ON sr.provider_id = sp.id
LEFT JOIN reviews r ON r.provider_id = sp.id
GROUP BY sp.id, u.full_name, sp.service_type, sp.is_available
ORDER BY average_rating DESC, completed_jobs DESC;


-- ============================================================================
-- Query 3: GROUP BY and HAVING with Multiple Aggregate Functions
-- Description: Identifies problem hotspots by department and village, filtering
-- only those departments that have at least 1 reported issue.
-- ============================================================================
SELECT 
    COALESCE(department, 'Uncategorized') AS department,
    COALESCE(village, 'Global / Central') AS village,
    COUNT(*) AS total_complaints,
    COUNT(*) FILTER (WHERE status = 'submitted') AS pending_triage,
    COUNT(*) FILTER (WHERE status = 'in_progress') AS active_investigation,
    COUNT(*) FILTER (WHERE status = 'resolved') AS resolved_count,
    ROUND((COUNT(*) FILTER (WHERE status = 'resolved')::numeric / COUNT(*)::numeric) * 100, 1) AS resolution_rate_pct,
    MIN(created_at) AS earliest_reported,
    MAX(created_at) AS latest_reported
FROM complaints
GROUP BY department, village
HAVING COUNT(*) >= 1
ORDER BY total_complaints DESC, resolution_rate_pct ASC;


-- ============================================================================
-- Query 4: Correlated Subquery
-- Description: Identifies agricultural products priced strictly ABOVE the average
-- product price within their specific category (e.g. Premium Fertilizers or Seeds).
-- ============================================================================
SELECT 
    p1.id AS product_id,
    p1.name AS product_name,
    p1.category,
    p1.price,
    p1.stock,
    s.name AS shop_name,
    (
        SELECT ROUND(AVG(p2.price)::numeric, 2)
        FROM products p2
        WHERE p2.category = p1.category
    ) AS category_avg_price,
    ROUND((p1.price - (SELECT AVG(p2.price) FROM products p2 WHERE p2.category = p1.category))::numeric, 2) AS price_diff_above_avg
FROM products p1
JOIN shops s ON s.id = p1.shop_id
WHERE p1.price > (
    SELECT AVG(p2.price)
    FROM products p2
    WHERE p2.category = p1.category
)
ORDER BY p1.category, p1.price DESC;


-- ============================================================================
-- Query 5: Subquery with Aggregate in HAVING Clause
-- Description: Finds complaints that have generated an unusually high level of
-- citizen engagement (more comments than the platform-wide average).
-- ============================================================================
SELECT 
    c.id AS complaint_id,
    c.title,
    c.department,
    c.status,
    COUNT(cc.id) AS comment_count
FROM complaints c
JOIN complaint_comments cc ON cc.complaint_id = c.id
GROUP BY c.id, c.title, c.department, c.status
HAVING COUNT(cc.id) > (
    SELECT COALESCE(AVG(comment_sub.cnt), 0)
    FROM (
        SELECT COUNT(*) AS cnt
        FROM complaint_comments
        GROUP BY complaint_id
    ) AS comment_sub
)
ORDER BY comment_count DESC;


-- ============================================================================
-- Query 6: Subquery with NOT EXISTS (Untapped Citizen Outreach)
-- Description: Identifies registered citizens who have never submitted any 
-- complaint or applied for any government welfare scheme.
-- ============================================================================
SELECT 
    u.id AS user_id,
    u.full_name,
    u.email,
    u.village,
    u.created_at AS joined_date
FROM users u
WHERE u.role = 'citizen'
  AND NOT EXISTS (
      SELECT 1 FROM complaints c WHERE c.citizen_id = u.id
  )
  AND NOT EXISTS (
      SELECT 1 FROM scheme_applications sa WHERE sa.citizen_id = u.id
  )
ORDER BY u.created_at DESC;


-- ============================================================================
-- Query 7: Subquery with EXISTS (Inventory Alert for Agro Shops)
-- Description: Identifies agricultural shops that have at least one product 
-- currently below its designated low-stock safety threshold.
-- ============================================================================
SELECT 
    s.id AS shop_id,
    s.name AS shop_name,
    s.location,
    u.full_name AS owner_name,
    u.phone AS owner_phone
FROM shops s
JOIN users u ON u.id = s.owner_id
WHERE EXISTS (
    SELECT 1 
    FROM products p 
    WHERE p.shop_id = s.id 
      AND p.stock <= p.low_stock_threshold
)
ORDER BY s.name;


-- ============================================================================
-- Query 8: Window Function Subquery (DENSE_RANK within Category)
-- Description: Partitions agricultural inventory by product category and ranks
-- each item from highest to lowest price.
-- ============================================================================
SELECT 
    ranked.category,
    ranked.product_name,
    ranked.price,
    ranked.stock,
    ranked.price_rank_in_category
FROM (
    SELECT 
        category,
        name AS product_name,
        price,
        stock,
        DENSE_RANK() OVER (PARTITION BY category ORDER BY price DESC) AS price_rank_in_category
    FROM products
) AS ranked
WHERE ranked.price_rank_in_category <= 3
ORDER BY ranked.category, ranked.price_rank_in_category;
