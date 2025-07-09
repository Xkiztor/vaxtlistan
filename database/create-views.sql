-- =====================================================================================
-- Database Views for Complex Queries
-- =====================================================================================
-- 
-- PURPOSE:
-- Creates materialized and regular views to optimize frequently used complex queries
-- and provide simplified interfaces for common data access patterns.
--
-- VIEWS TO CREATE:
--
-- 1. VIEW: available_plants_summary
--    - Pre-joins facit with totallager for available plants
--    - Includes basic stock and nursery counts
--    - Used by search functions to avoid repeated JOINs
--
-- 2. MATERIALIZED VIEW: plant_availability_stats
--    - Aggregated statistics for each plant (total stock, nursery count, price range)
--    - Refreshed periodically (hourly/daily)
--    - Improves performance for dashboard and statistics
--
-- 3. VIEW: plantskola_active_inventory
--    - Shows only active (non-hidden, in-stock) plants per nursery
--    - Used in admin interfaces and public plant listings
--    - Filters out hidden plants and nurseries
--
-- 4. VIEW: plant_search_index
--    - Optimized view for search operations
--    - Pre-sanitized names for faster searching
--    - Includes search-relevant fields only
--
-- 5. MATERIALIZED VIEW: popular_plants
--    - Most searched/viewed plants with availability info
--    - Used for recommendations and trending plants
--    - Refreshed based on usage analytics
--
-- REFRESH STRATEGIES:
-- - Real-time views: Regular views that always show current data
-- - Cached views: Materialized views refreshed on schedule
-- - Trigger-based: Auto-refresh on data changes
-- - Manual refresh: For heavy analytical queries
--
-- PERFORMANCE BENEFITS:
-- - Reduced JOIN complexity in application queries
-- - Pre-computed aggregations for dashboard metrics
-- - Simplified query interfaces for frontend
-- - Better query plan optimization
-- - Reduced database load for frequent operations
--
-- MAINTENANCE:
-- - Schedule materialized view refreshes
-- - Monitor view usage and performance
-- - Update view definitions as schema evolves
-- - Consider partitioning for large materialized views
--
-- TODO FOR AI IMPLEMENTATION:
-- 1. Create available_plants_summary view with facit + totallager JOIN
-- 2. Build plant_availability_stats materialized view with aggregations
-- 3. Create plantskola_active_inventory with proper filtering
-- 4. Design plant_search_index view with sanitized names
-- 5. Implement popular_plants materialized view structure
-- 6. Add refresh procedures for materialized views
-- 7. Create indexes on materialized views
-- 8. Add view dependency management
-- 9. Include performance monitoring queries
-- 10. Document view refresh schedules and strategies
-- =====================================================================================

-- =====================================================================================
-- 1. VIEW: available_plants_summary
-- Pre-joins facit with totallager for available plants with basic stock and nursery counts
-- =====================================================================================

CREATE OR REPLACE VIEW available_plants_summary AS
SELECT 
    f.id,
    f.name,
    f.sv_name,
    f.plant_type,
    f.taxonomy_type,
    f.is_synonym,
    f.synonym_to,
    f.synonym_to_id,
    f.has_synonyms,
    f.height,
    f.spread,
    f.sunlight,
    f.soil_type,
    f.moisture,
    f.ph,
    f.colors,
    COUNT(tl.id) as nursery_count,
    SUM(CASE WHEN tl.stock IS NOT NULL THEN tl.stock ELSE 0 END) as total_stock,
    COUNT(CASE WHEN tl.stock > 0 OR tl.stock IS NULL THEN 1 END) as available_nurseries,
    MIN(tl.price) as min_price,
    MAX(tl.price) as max_price,
    ROUND(AVG(tl.price), 2) as avg_price
FROM facit f
INNER JOIN totallager tl ON f.id = tl.facit_id
INNER JOIN plantskolor p ON tl.plantskola_id = p.id
WHERE 
    tl.hidden = false 
    AND p.hidden = false 
    AND p.verified = true
    AND (tl.stock > 0 OR tl.stock IS NULL) -- Include plants with unknown stock
GROUP BY 
    f.id, f.name, f.sv_name, f.plant_type, f.taxonomy_type, 
    f.is_synonym, f.synonym_to, f.synonym_to_id, f.has_synonyms, f.height, f.spread, f.sunlight, f.soil_type, 
    f.moisture, f.ph, f.colors;

-- =====================================================================================
-- 2. MATERIALIZED VIEW: plant_availability_stats
-- Aggregated statistics for each plant with refresh capability
-- =====================================================================================

CREATE MATERIALIZED VIEW IF NOT EXISTS plant_availability_stats AS
SELECT 
    f.id,
    f.name,
    f.sv_name,
    f.plant_type,
    f.taxonomy_type,
    COUNT(DISTINCT tl.plantskola_id) as total_nurseries,
    COUNT(DISTINCT CASE WHEN tl.stock > 0 OR tl.stock IS NULL THEN tl.plantskola_id END) as available_nurseries,
    SUM(CASE WHEN tl.stock IS NOT NULL THEN tl.stock ELSE 0 END) as total_confirmed_stock,
    COUNT(CASE WHEN tl.stock IS NULL THEN 1 END) as unknown_stock_entries,
    MIN(tl.price) as min_price,
    MAX(tl.price) as max_price,
    ROUND(AVG(tl.price), 2) as avg_price,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY tl.price) as median_price,
    COUNT(DISTINCT tl.pot) as pot_variety_count,
    ARRAY_AGG(DISTINCT tl.pot ORDER BY tl.pot) FILTER (WHERE tl.pot IS NOT NULL) as available_pot_sizes,
    ARRAY_AGG(DISTINCT p.name ORDER BY p.name) as nursery_names,
    NOW() as last_refreshed
FROM facit f
INNER JOIN totallager tl ON f.id = tl.facit_id
INNER JOIN plantskolor p ON tl.plantskola_id = p.id
WHERE 
    tl.hidden = false 
    AND p.hidden = false 
    AND p.verified = true
GROUP BY f.id, f.name, f.sv_name, f.plant_type, f.taxonomy_type;

-- Create index on materialized view for faster queries
CREATE INDEX IF NOT EXISTS idx_plant_availability_stats_name ON plant_availability_stats USING gin(to_tsvector('swedish', name || ' ' || COALESCE(sv_name, '')));
CREATE INDEX IF NOT EXISTS idx_plant_availability_stats_plant_type ON plant_availability_stats (plant_type);
CREATE INDEX IF NOT EXISTS idx_plant_availability_stats_available_nurseries ON plant_availability_stats (available_nurseries);

-- =====================================================================================
-- 3. VIEW: plantskola_active_inventory
-- Shows only active (non-hidden, in-stock) plants per nursery
-- =====================================================================================

CREATE OR REPLACE VIEW plantskola_active_inventory AS
SELECT 
    p.id as plantskola_id,
    p.name as plantskola_name,
    p.adress,
    p.email,
    p.phone,
    p.url,
    p.postorder,
    p.on_site,
    p.description as plantskola_description,
    tl.id as lager_id,
    tl.facit_id,
    f.name as plant_name,
    f.sv_name as plant_sv_name,
    f.plant_type,
    f.taxonomy_type,
    tl.name_by_plantskola,
    tl.comment_by_plantskola,
    tl.id_by_plantskola,
    tl.pot,
    tl.height,
    tl.price,
    tl.stock,
    tl.own_columns,
    tl.created_at,
    tl.last_edited
FROM plantskolor p
INNER JOIN totallager tl ON p.id = tl.plantskola_id
INNER JOIN facit f ON tl.facit_id = f.id
WHERE 
    p.hidden = false 
    AND p.verified = true
    AND tl.hidden = false
    AND (tl.stock > 0 OR tl.stock IS NULL); -- Include unknown stock

-- =====================================================================================
-- 4. VIEW: plant_search_index
-- Optimized view for search operations with pre-sanitized names
-- =====================================================================================

CREATE OR REPLACE VIEW plant_search_index AS
SELECT 
    f.id,
    f.name,
    f.sv_name,
    -- Sanitized names for faster searching
    LOWER(REGEXP_REPLACE(
        REGEXP_REPLACE(
            REGEXP_REPLACE(f.name, '[''"`´]', '', 'g'), -- Remove quotes
            '[åä]', 'a', 'g'
        ),
        '[ö]', 'o', 'g'
    )) as sanitized_name,
    LOWER(REGEXP_REPLACE(
        REGEXP_REPLACE(
            REGEXP_REPLACE(COALESCE(f.sv_name, ''), '[''"`´]', '', 'g'),
            '[åä]', 'a', 'g'
        ),
        '[ö]', 'o', 'g'
    )) as sanitized_sv_name,
    f.plant_type,
    f.taxonomy_type,
    f.is_synonym,
    f.synonym_to,
    f.synonym_to_id,
    f.has_synonyms,
    f.user_submitted,
    -- Full text search vectors
    to_tsvector('swedish', f.name || ' ' || COALESCE(f.sv_name, '')) as search_vector,
    -- Availability info
    EXISTS(
        SELECT 1 FROM totallager tl 
        INNER JOIN plantskolor p ON tl.plantskola_id = p.id
        WHERE tl.facit_id = f.id 
        AND tl.hidden = false 
        AND p.hidden = false 
        AND p.verified = true
        AND (tl.stock > 0 OR tl.stock IS NULL)
    ) as is_available
FROM facit f;

-- =====================================================================================
-- 5. MATERIALIZED VIEW: popular_plants
-- Most searched/viewed plants with availability info (placeholder for future analytics)
-- =====================================================================================

CREATE MATERIALIZED VIEW IF NOT EXISTS popular_plants AS
SELECT 
    f.id,
    f.name,
    f.sv_name,
    f.plant_type,
    f.taxonomy_type,
    -- Popularity metrics (placeholder - will need actual search/view tracking)
    COUNT(tl.id) as listing_count,
    COUNT(DISTINCT tl.plantskola_id) as nursery_count,
    SUM(CASE WHEN tl.stock IS NOT NULL THEN tl.stock ELSE 0 END) as total_stock,
    MIN(tl.price) as min_price,
    MAX(tl.price) as max_price,
    ROUND(AVG(tl.price), 2) as avg_price,
    -- Synthetic popularity score based on availability
    (COUNT(DISTINCT tl.plantskola_id) * 10 + 
     COUNT(tl.id) * 5 + 
     CASE WHEN SUM(CASE WHEN tl.stock IS NOT NULL THEN tl.stock ELSE 0 END) > 0 
          THEN LOG(SUM(CASE WHEN tl.stock IS NOT NULL THEN tl.stock ELSE 0 END) + 1) * 2 
          ELSE 0 END
    ) as popularity_score,
    NOW() as last_refreshed
FROM facit f
INNER JOIN totallager tl ON f.id = tl.facit_id
INNER JOIN plantskolor p ON tl.plantskola_id = p.id
WHERE 
    tl.hidden = false 
    AND p.hidden = false 
    AND p.verified = true
    AND (tl.stock > 0 OR tl.stock IS NULL)
GROUP BY f.id, f.name, f.sv_name, f.plant_type, f.taxonomy_type
HAVING COUNT(DISTINCT tl.plantskola_id) >= 2 -- Only include plants available at 2+ nurseries
ORDER BY popularity_score DESC
LIMIT 1000; -- Top 1000 popular plants

-- Create indexes on popular_plants materialized view
CREATE INDEX IF NOT EXISTS idx_popular_plants_popularity_score ON popular_plants (popularity_score DESC);
CREATE INDEX IF NOT EXISTS idx_popular_plants_plant_type ON popular_plants (plant_type);

-- =====================================================================================
-- REFRESH PROCEDURES FOR MATERIALIZED VIEWS
-- =====================================================================================

-- Function to refresh plant availability stats
CREATE OR REPLACE FUNCTION refresh_plant_availability_stats()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY plant_availability_stats;
    -- Log refresh time for monitoring
    INSERT INTO materialized_view_refresh_log (view_name, refreshed_at)
    VALUES ('plant_availability_stats', NOW())
    ON CONFLICT (view_name) DO UPDATE SET 
        refreshed_at = NOW(),
        refresh_count = materialized_view_refresh_log.refresh_count + 1;
END;
$$ LANGUAGE plpgsql;

-- Function to refresh popular plants
CREATE OR REPLACE FUNCTION refresh_popular_plants()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY popular_plants;
    -- Log refresh time for monitoring
    INSERT INTO materialized_view_refresh_log (view_name, refreshed_at)
    VALUES ('popular_plants', NOW())
    ON CONFLICT (view_name) DO UPDATE SET 
        refreshed_at = NOW(),
        refresh_count = materialized_view_refresh_log.refresh_count + 1;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================================
-- REFRESH LOG TABLE
-- =====================================================================================

CREATE TABLE IF NOT EXISTS materialized_view_refresh_log (
    view_name TEXT PRIMARY KEY,
    refreshed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    refresh_count INTEGER NOT NULL DEFAULT 1
);

-- =====================================================================================
-- VIEW DEPENDENCY MANAGEMENT
-- =====================================================================================

-- Function to check view dependencies before dropping/recreating
CREATE OR REPLACE FUNCTION check_view_dependencies(view_name TEXT)
RETURNS TABLE(dependent_view TEXT) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT d.objid::regclass::text
    FROM pg_depend d
    JOIN pg_rewrite r ON r.oid = d.objid
    JOIN pg_class c ON c.oid = r.ev_class
    WHERE d.refobjid = view_name::regclass::oid
    AND d.deptype = 'n'
    AND c.relkind = 'v';
END;
$$ LANGUAGE plpgsql;

-- =====================================================================================
-- PERFORMANCE MONITORING FOR VIEWS
-- =====================================================================================

-- Query to monitor view usage
CREATE OR REPLACE VIEW view_usage_stats AS
SELECT 
    schemaname,
    relname as viewname,
    n_tup_ins,
    n_tup_upd,
    n_tup_del,
    n_tup_hot_upd,
    n_live_tup,
    n_dead_tup,
    vacuum_count,
    autovacuum_count,
    analyze_count,
    autoanalyze_count
FROM pg_stat_user_tables 
WHERE schemaname = 'public'
UNION ALL
SELECT 
    'public' as schemaname,
    t.relname as viewname,
    0 as n_tup_ins,
    0 as n_tup_upd, 
    0 as n_tup_del,
    0 as n_tup_hot_upd,
    t.n_live_tup,
    t.n_dead_tup,
    0 as vacuum_count,
    0 as autovacuum_count,
    0 as analyze_count,
    0 as autoanalyze_count
FROM pg_stat_user_tables t
JOIN pg_class c ON c.oid = t.relid
WHERE c.relkind = 'm'; -- Materialized views
