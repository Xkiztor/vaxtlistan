-- =====================================================================================
-- Plant Popularity Ranking System
-- =====================================================================================
-- 
-- PURPOSE:
-- Implements a comprehensive popularity ranking system based on page views.
-- Includes analytics tracking, popularity score calculation, and integration
-- with the existing search system.
--
-- FEATURES:
-- - Daily page view tracking per plant
-- - Time-weighted popularity scoring (recent views count more)
-- - Efficient batch processing for score updates
-- - Integration with search_plants_main_page function
-- - Performance optimized with proper indexing
--
-- COMPONENTS:
-- 1. plant_analytics table for tracking daily views
-- 2. popularity_score column in facit table (cached scores)
-- 3. Functions for tracking views and updating scores
-- 4. Indexes for optimal performance
-- 5. Updated search function with popularity sorting
--
-- =====================================================================================

-- =====================================================================================
-- 1. Create Analytics Table
-- =====================================================================================

-- Table to store daily page view counts per plant
CREATE TABLE IF NOT EXISTS plant_analytics (
    id BIGSERIAL PRIMARY KEY,
    facit_id BIGINT NOT NULL REFERENCES facit(id) ON DELETE CASCADE,
    view_date DATE NOT NULL DEFAULT CURRENT_DATE,
    view_count INTEGER NOT NULL DEFAULT 1,
    last_updated TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Ensure one record per plant per day
    UNIQUE(facit_id, view_date)
);

-- =====================================================================================
-- 2. Add Popularity Score Column to Facit
-- =====================================================================================

-- Add cached popularity score column for fast sorting
ALTER TABLE facit ADD COLUMN IF NOT EXISTS popularity_score NUMERIC DEFAULT 0;

-- =====================================================================================
-- 3. Create Indexes for Performance
-- =====================================================================================

-- Analytics table indexes
CREATE INDEX IF NOT EXISTS idx_plant_analytics_facit_id ON plant_analytics(facit_id);
CREATE INDEX IF NOT EXISTS idx_plant_analytics_date ON plant_analytics(view_date DESC);
CREATE INDEX IF NOT EXISTS idx_plant_analytics_composite ON plant_analytics(facit_id, view_date DESC);
-- Removed immutable function issue - create partial index manually if needed
-- CREATE INDEX IF NOT EXISTS idx_plant_analytics_recent_views ON plant_analytics(view_date DESC, facit_id) WHERE view_date >= CURRENT_DATE - INTERVAL '365 days';

-- Facit table popularity index
CREATE INDEX IF NOT EXISTS idx_facit_popularity_score ON facit(popularity_score DESC);
CREATE INDEX IF NOT EXISTS idx_facit_popularity_score_composite ON facit(popularity_score DESC, id) WHERE popularity_score > 0;

-- =====================================================================================
-- 4. Function to Track Plant Page Views
-- =====================================================================================

-- Efficiently track a plant page view with upsert
CREATE OR REPLACE FUNCTION track_plant_view(p_facit_id BIGINT)
RETURNS void AS $$
BEGIN
    -- Insert new record or increment existing daily count
    INSERT INTO plant_analytics (facit_id, view_date, view_count, last_updated)
    VALUES (p_facit_id, CURRENT_DATE, 1, NOW())
    ON CONFLICT (facit_id, view_date)
    DO UPDATE SET 
        view_count = plant_analytics.view_count + 1,
        last_updated = NOW();
    
EXCEPTION WHEN OTHERS THEN
    -- Log error but don't fail - analytics shouldn't break the app
    RAISE WARNING 'Failed to track plant view for facit_id %: %', p_facit_id, SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================================
-- 5. Function to Calculate and Update Popularity Scores
-- =====================================================================================

-- Calculate time-weighted popularity scores and update facit table
CREATE OR REPLACE FUNCTION update_plant_popularity_scores()
RETURNS TABLE(
    updated_count INTEGER,
    execution_time_ms NUMERIC
) AS $$
DECLARE
    v_start_time TIMESTAMPTZ;
    v_updated_count INTEGER;
BEGIN
    v_start_time := clock_timestamp();
    
    -- Update popularity scores based on time-weighted view data
    WITH popularity_calculations AS (
        SELECT 
            facit_id,
            -- Time-weighted scoring: recent views have higher weight
            SUM(
                view_count * 
                CASE 
                    -- Last 7 days: 10x weight
                    WHEN view_date >= CURRENT_DATE - INTERVAL '7 days' THEN 10.0
                    -- Last 30 days: 5x weight
                    WHEN view_date >= CURRENT_DATE - INTERVAL '30 days' THEN 5.0
                    -- Last 90 days: 2x weight
                    WHEN view_date >= CURRENT_DATE - INTERVAL '90 days' THEN 2.0
                    -- Last 365 days: 1x weight
                    WHEN view_date >= CURRENT_DATE - INTERVAL '365 days' THEN 1.0
                    -- Older than 1 year: minimal weight
                    ELSE 0.1
                END
            )::NUMERIC as score
        FROM plant_analytics
        WHERE view_date >= CURRENT_DATE - INTERVAL '2 years' -- Consider last 2 years
        GROUP BY facit_id
    )
    UPDATE facit 
    SET popularity_score = COALESCE(popularity_calculations.score, 0)
    FROM popularity_calculations
    WHERE facit.id = popularity_calculations.facit_id;
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    
    -- Also reset scores for plants with no recent views
    UPDATE facit 
    SET popularity_score = 0 
    WHERE id NOT IN (
        SELECT DISTINCT facit_id 
        FROM plant_analytics 
        WHERE view_date >= CURRENT_DATE - INTERVAL '2 years'
    ) AND popularity_score > 0;
    
    RETURN QUERY SELECT 
        v_updated_count,
        EXTRACT(EPOCH FROM (clock_timestamp() - v_start_time)) * 1000;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================================
-- 6. Function to Get Popularity Statistics
-- =====================================================================================


-- NOT USED YET
-- Get detailed popularity statistics for monitoring

CREATE OR REPLACE FUNCTION get_popularity_statistics()
RETURNS TABLE(
    total_plants_with_views BIGINT,
    total_views_last_7_days BIGINT,
    total_views_last_30_days BIGINT,
    total_views_last_365_days BIGINT,
    avg_popularity_score NUMERIC,
    max_popularity_score NUMERIC,
    top_plant_id BIGINT,
    top_plant_name TEXT,
    last_score_update TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    WITH stats AS (
        SELECT 
            COUNT(DISTINCT pa.facit_id) as plants_with_views,
            SUM(CASE WHEN pa.view_date >= CURRENT_DATE - INTERVAL '7 days' THEN pa.view_count ELSE 0 END) as views_7d,
            SUM(CASE WHEN pa.view_date >= CURRENT_DATE - INTERVAL '30 days' THEN pa.view_count ELSE 0 END) as views_30d,
            SUM(CASE WHEN pa.view_date >= CURRENT_DATE - INTERVAL '365 days' THEN pa.view_count ELSE 0 END) as views_365d
        FROM plant_analytics pa
        WHERE pa.view_date >= CURRENT_DATE - INTERVAL '365 days'
    ),
    facit_stats AS (
        SELECT 
            AVG(popularity_score) as avg_score,
            MAX(popularity_score) as max_score
        FROM facit 
        WHERE popularity_score > 0
    ),
    top_plant AS (
        SELECT f.id, f.name
        FROM facit f
        WHERE f.popularity_score = (SELECT MAX(popularity_score) FROM facit)
        LIMIT 1
    )
    SELECT 
        s.plants_with_views,
        s.views_7d,
        s.views_30d,
        s.views_365d,
        ROUND(fs.avg_score, 2),
        fs.max_score,
        tp.id,
        tp.name,
        (SELECT MAX(last_updated) FROM plant_analytics WHERE view_date >= CURRENT_DATE - INTERVAL '7 days')
    FROM stats s, facit_stats fs, top_plant tp;
END;
$$ LANGUAGE plpgsql;


-- =====================================================================================
-- 8. Maintenance and Monitoring
-- =====================================================================================

-- Create a log table for tracking popularity score updates
CREATE TABLE IF NOT EXISTS popularity_update_log (
    id BIGSERIAL PRIMARY KEY,
    update_timestamp TIMESTAMPTZ DEFAULT NOW(),
    plants_updated INTEGER,
    execution_time_ms NUMERIC,
    notes TEXT
);

-- Function to run daily maintenance with logging
CREATE OR REPLACE FUNCTION run_daily_popularity_maintenance()
RETURNS void AS $$
DECLARE
    v_result RECORD;
BEGIN
    -- Update popularity scores
    SELECT * INTO v_result FROM update_plant_popularity_scores();
    
    -- Log the update
    INSERT INTO popularity_update_log (plants_updated, execution_time_ms, notes)
    VALUES (v_result.updated_count, v_result.execution_time_ms, 'Daily automated update');
    
    -- Clean up old analytics data (keep 2 years)
    DELETE FROM plant_analytics 
    WHERE view_date < CURRENT_DATE - INTERVAL '2 years';
    
    -- Clean up old logs (keep 90 days)
    DELETE FROM popularity_update_log 
    WHERE update_timestamp < NOW() - INTERVAL '90 days';
    
END;
$$ LANGUAGE plpgsql;

-- =====================================================================================
-- 9. Initial Setup and Data Migration
-- =====================================================================================

-- Initialize popularity scores for existing plants (can be run safely multiple times)
DO $$
BEGIN
    -- Set initial popularity scores to 0 for all plants if not already set
    UPDATE facit 
    SET popularity_score = 0 
    WHERE popularity_score IS NULL;
    
    RAISE NOTICE 'Initial popularity scores set for all plants';
END
$$;

-- =====================================================================================
-- 10. Usage Examples and Comments
-- =====================================================================================

/*
-- EXAMPLE USAGE:

-- 1. Track a plant page view
SELECT track_plant_view(12345);

-- 2. Update all popularity scores (run daily)
SELECT * FROM update_plant_popularity_scores();

-- 3. Get popularity statistics
SELECT * FROM get_popularity_statistics();

-- 4. Search with popularity sorting
SELECT * FROM search_plants_main_page(
    'rosa', 
    '{"sort_by": "popularity"}', 
    false, 
    20, 
    0
);

-- 5. Run daily maintenance
SELECT run_daily_popularity_maintenance();

-- CRON JOB SETUP:
-- Add this to your system cron or database scheduler:
-- 0 2 * * * psql -d your_database -c "SELECT run_daily_popularity_maintenance();"

-- MONITORING QUERIES:
-- Check recent activity:
SELECT * FROM plant_analytics WHERE view_date >= CURRENT_DATE - INTERVAL '7 days' ORDER BY view_count DESC LIMIT 10;

-- Check top plants by popularity:
SELECT f.name, f.sv_name, f.popularity_score 
FROM facit f 
WHERE f.popularity_score > 0 
ORDER BY f.popularity_score DESC 
LIMIT 10;

-- Check popularity update history:
SELECT * FROM popularity_update_log ORDER BY update_timestamp DESC LIMIT 5;
*/

-- =====================================================================================
-- End of Plant Popularity System Implementation
-- =====================================================================================
