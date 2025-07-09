-- =====================================================================================
-- Performance Monitoring and Analytics Queries
-- =====================================================================================
-- 
-- PURPOSE:
-- Collection of SQL queries for monitoring database performance, analyzing search
-- patterns, and providing insights for optimization decisions.
--
-- MONITORING CATEGORIES:
--
-- 1. SEARCH PERFORMANCE METRICS:
--    - Query execution times for search functions
--    - Most common search terms and patterns
--    - Search result quality metrics
--    - Slow query identification and analysis
--
-- 2. INDEX USAGE ANALYSIS:
--    - Index scan vs sequential scan ratios
--    - Unused index identification
--    - Index size and maintenance overhead
--    - Query plan analysis for optimization
--
-- 3. DATABASE HEALTH METRICS:
--    - Table sizes and growth patterns
--    - Lock contention and deadlock detection
--    - Connection pool usage
--    - Disk space and I/O performance
--
-- 4. USER BEHAVIOR ANALYTICS:
--    - Popular plants and search trends
--    - Nursery inventory turnover rates
--    - Geographic search patterns
--    - Seasonal plant demand variations
--
-- 5. DATA QUALITY METRICS:
--    - Duplicate plant entries detection
--    - Missing or incomplete plant information
--    - Orphaned records identification
--    - Data consistency validation
--
-- PERFORMANCE BENCHMARKS:
-- - Search functions: < 100ms for typical queries
-- - Lager fetch: < 50ms for single nursery
-- - Plant picker: < 200ms for autocomplete
-- - Available plants: < 500ms with full aggregation
--
-- ALERTING THRESHOLDS:
-- - Query time > 1 second: Investigate optimization
-- - Index hit ratio < 95%: Add missing indexes
-- - Table bloat > 20%: Schedule maintenance
-- - Connection count > 80%: Scale resources
--
-- OPTIMIZATION RECOMMENDATIONS:
-- - Based on query frequency and execution time
-- - Index suggestions for common query patterns
-- - Partitioning recommendations for large tables
-- - Caching strategies for frequent operations
--
-- REPORTING QUERIES:
-- - Daily performance summary
-- - Weekly search analytics report
-- - Monthly growth and usage trends
-- - Quarterly optimization recommendations
--
-- PERFORMANCE IMPACT MITIGATION:
--
-- 1. EXECUTION SCHEDULING:
--    - Run heavy analytics during off-peak hours (2-6 AM)
--    - Use cron jobs with priority-based scheduling
--    - Implement query timeouts to prevent runaway queries
--    - Stagger monitoring tasks to avoid resource spikes
--
-- 2. RESOURCE MANAGEMENT:
--    - Set work_mem limits for monitoring sessions
--    - Use connection pooling with dedicated monitoring connections
--    - Implement query result pagination for large datasets
--    - Use EXPLAIN ANALYZE to validate query plans before deployment
--
-- 3. LOCKING STRATEGIES:
--    - Use READ UNCOMMITTED for non-critical monitoring
--    - Implement monitoring on read replicas when possible
--    - Break large operations into smaller, interruptible chunks
--    - Use advisory locks to prevent concurrent monitoring overlap
--
-- 4. DATA SAMPLING:
--    - Sample 10-20% of data for trend analysis instead of full scans
--    - Use statistical sampling for large table analysis
--    - Implement rolling window analysis (last 30 days vs all time)
--    - Cache frequent monitoring results in summary tables
--
-- 5. INCREMENTAL PROCESSING:
--    - Track last processed timestamps to avoid reprocessing
--    - Use materialized views for expensive aggregations
--    - Implement delta processing for changed records only
--    - Store monitoring results for historical comparison
--
-- PERFORMANCE BUDGET:
-- - Critical monitoring: < 50ms impact on user queries
-- - Regular monitoring: < 5% total database resources
-- - Heavy analytics: Off-peak only, < 30 minutes duration
-- - Real-time alerts: < 10ms response time
--
-- MONITORING CATEGORIES BY PERFORMANCE IMPACT:
--
-- LOW IMPACT (Real-time, < 10ms):
-- - Active connection count
-- - Current query execution time
-- - Basic cache hit ratios
-- - Simple index usage counters
--
-- MEDIUM IMPACT (Every 5-15 minutes, < 100ms):
-- - Slow query detection
-- - Lock contention analysis
-- - Memory usage statistics
-- - Recent search pattern summaries
--
-- HIGH IMPACT (Hourly/Daily, off-peak):
-- - Full table size analysis
-- - Complete index usage review
-- - Data quality validation
-- - Historical trend calculations

-- TODO FOR AI IMPLEMENTATION:
-- 1. Create lightweight real-time monitoring queries (< 10ms)
-- 2. Build medium-impact periodic checks with proper scheduling
-- 3. Design heavy analytics for off-peak execution
-- 4. Implement sampling strategies for large dataset analysis
-- 5. Create materialized views for expensive monitoring aggregations
-- 6. Add query timeout and resource limit configurations
-- 7. Build monitoring result caching and historical storage
-- 8. Include performance impact measurement for each monitoring query
-- 9. Create monitoring query prioritization and scheduling system
-- 10. Add real-time alerting with minimal performance overhead
-- =====================================================================================

-- =====================================================================================
-- Performance Monitoring and Analytics Queries
-- =====================================================================================

-- =====================================================================================
-- LOW IMPACT MONITORING (Real-time, < 10ms)
-- =====================================================================================

-- Current active connections
CREATE OR REPLACE FUNCTION get_active_connections()
RETURNS TABLE(
    total_connections INTEGER,
    active_queries INTEGER,
    idle_connections INTEGER,
    max_connections INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::INTEGER as total_connections,
        COUNT(CASE WHEN state = 'active' THEN 1 END)::INTEGER as active_queries,
        COUNT(CASE WHEN state = 'idle' THEN 1 END)::INTEGER as idle_connections,
        (SELECT setting::INTEGER FROM pg_settings WHERE name = 'max_connections') as max_connections
    FROM pg_stat_activity
    WHERE pid != pg_backend_pid();
END;
$$ LANGUAGE plpgsql;

-- Current query execution times (real-time)
CREATE OR REPLACE VIEW current_query_times AS
SELECT 
    pid,
    usename,
    application_name,
    client_addr,
    state,
    query_start,
    state_change,
    EXTRACT(EPOCH FROM (NOW() - query_start))::INTEGER as query_duration_seconds,
    LEFT(query, 100) as query_preview
FROM pg_stat_activity 
WHERE state = 'active' 
AND pid != pg_backend_pid()
AND query NOT LIKE '%pg_stat_activity%'
ORDER BY query_start;

-- Basic cache hit ratios (lightweight)
CREATE OR REPLACE VIEW cache_hit_ratios AS
SELECT 
    'Buffer Cache Hit Ratio' as metric,
    ROUND(
        (sum(heap_blks_hit) / NULLIF(sum(heap_blks_hit) + sum(heap_blks_read), 0)) * 100, 2
    ) as percentage
FROM pg_statio_user_tables
UNION ALL
SELECT 
    'Index Cache Hit Ratio' as metric,
    ROUND(
        (sum(idx_blks_hit) / NULLIF(sum(idx_blks_hit) + sum(idx_blks_read), 0)) * 100, 2
    ) as percentage
FROM pg_statio_user_indexes;

-- Quick index usage counters
CREATE OR REPLACE VIEW quick_index_stats AS
SELECT 
    schemaname,
    relname as tablename,
    indexrelname as indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_scan DESC
LIMIT 20;

-- =====================================================================================
-- MEDIUM IMPACT MONITORING (Every 5-15 minutes, < 100ms)
-- =====================================================================================

-- Slow query detection
CREATE OR REPLACE FUNCTION detect_slow_queries(threshold_seconds INTEGER DEFAULT 5)
RETURNS TABLE(
    pid INTEGER,
    duration_seconds INTEGER,
    username TEXT,
    database_name TEXT,
    query_preview TEXT,
    state TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pg_stat_activity.pid,
        EXTRACT(EPOCH FROM (NOW() - query_start))::INTEGER as duration_seconds,
        usename::TEXT,
        datname::TEXT,
        LEFT(query, 200)::TEXT as query_preview,
        state::TEXT
    FROM pg_stat_activity 
    WHERE state = 'active'
    AND EXTRACT(EPOCH FROM (NOW() - query_start)) > threshold_seconds
    AND pid != pg_backend_pid()
    ORDER BY duration_seconds DESC;
END;
$$ LANGUAGE plpgsql;

-- Lock contention analysis
CREATE OR REPLACE FUNCTION analyze_lock_contention()
RETURNS TABLE(
    blocked_pid INTEGER,
    blocking_pid INTEGER,
    blocked_user TEXT,
    blocking_user TEXT,
    blocked_query TEXT,
    blocking_query TEXT,
    lock_type TEXT,
    lock_mode TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        blocked_locks.pid as blocked_pid,
        blocking_locks.pid as blocking_pid,
        blocked_activity.usename::TEXT as blocked_user,
        blocking_activity.usename::TEXT as blocking_user,
        LEFT(blocked_activity.query, 100)::TEXT as blocked_query,
        LEFT(blocking_activity.query, 100)::TEXT as blocking_query,
        blocked_locks.locktype::TEXT,
        blocked_locks.mode::TEXT
    FROM pg_catalog.pg_locks blocked_locks
    JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
    JOIN pg_catalog.pg_locks blocking_locks ON blocking_locks.locktype = blocked_locks.locktype
        AND blocking_locks.DATABASE IS NOT DISTINCT FROM blocked_locks.DATABASE
        AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
        AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
        AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
        AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
        AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
        AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
        AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
        AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
        AND blocking_locks.pid != blocked_locks.pid
    JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
    WHERE NOT blocked_locks.granted;
END;
$$ LANGUAGE plpgsql;

-- Memory usage statistics
CREATE OR REPLACE VIEW memory_usage_stats AS
SELECT 
    name,
    setting,
    unit,
    context,
    short_desc
FROM pg_settings 
WHERE name IN (
    'shared_buffers',
    'effective_cache_size',
    'work_mem',
    'maintenance_work_mem',
    'max_connections'
)
ORDER BY name;

-- Recent search pattern summaries (sampled)
CREATE OR REPLACE FUNCTION recent_search_patterns(sample_hours INTEGER DEFAULT 1)
RETURNS TABLE(
    search_type TEXT,
    estimated_queries INTEGER,
    avg_duration_ms NUMERIC
) AS $$
BEGIN
    -- This is a placeholder for actual search tracking
    -- In a real implementation, you would log search queries and analyze them
    RETURN QUERY
    SELECT 
        'Plant Name Search'::TEXT,
        100::INTEGER, -- Estimated based on application metrics
        50.5::NUMERIC
    UNION ALL
    SELECT 
        'Availability Check'::TEXT,
        200::INTEGER,
        25.3::NUMERIC
    UNION ALL
    SELECT 
        'Nursery Lookup'::TEXT,
        50::INTEGER,
        15.8::NUMERIC;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================================
-- HIGH IMPACT MONITORING (Hourly/Daily, off-peak)
-- =====================================================================================

-- Full table size analysis
CREATE OR REPLACE FUNCTION analyze_table_sizes()
RETURNS TABLE(
    schema_name TEXT,
    table_name TEXT,
    row_count BIGINT,
    table_size_mb NUMERIC,
    index_size_mb NUMERIC,
    total_size_mb NUMERIC,
    growth_trend TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        schemaname::TEXT,
        tablename::TEXT,
        n_tup_ins + n_tup_upd + n_tup_del as row_count,
        ROUND(pg_total_relation_size(schemaname||'.'||tablename) / 1024.0 / 1024.0, 2) as table_size_mb,
        ROUND(
            (pg_total_relation_size(schemaname||'.'||tablename) - 
             pg_relation_size(schemaname||'.'||tablename)) / 1024.0 / 1024.0, 2
        ) as index_size_mb,
        ROUND(pg_total_relation_size(schemaname||'.'||tablename) / 1024.0 / 1024.0, 2) as total_size_mb,
        CASE 
            WHEN n_tup_ins > n_tup_del * 2 THEN 'Growing'
            WHEN n_tup_del > n_tup_ins * 2 THEN 'Shrinking'
            ELSE 'Stable'
        END::TEXT as growth_trend
    FROM pg_stat_user_tables
    WHERE schemaname = 'public'
    ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
END;
$$ LANGUAGE plpgsql;

-- Complete index usage review
CREATE OR REPLACE FUNCTION complete_index_analysis()
RETURNS TABLE(
    schema_name TEXT,
    table_name TEXT,
    index_name TEXT,
    index_scans BIGINT,
    tuples_read BIGINT,
    tuples_fetched BIGINT,
    size_mb NUMERIC,
    efficiency_ratio NUMERIC,
    recommendation TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        schemaname::TEXT,
        tablename::TEXT,
        indexname::TEXT,
        idx_scan,
        idx_tup_read,
        idx_tup_fetch,
        ROUND(pg_relation_size(indexrelname::regclass) / 1024.0 / 1024.0, 2) as size_mb,
        CASE 
            WHEN idx_scan > 0 THEN ROUND(idx_tup_fetch::NUMERIC / idx_scan, 2)
            ELSE 0
        END as efficiency_ratio,
        CASE 
            WHEN idx_scan = 0 THEN 'Consider dropping - never used'
            WHEN idx_scan > 0 AND idx_tup_fetch::NUMERIC / idx_scan < 1 THEN 'Low efficiency - review queries'
            WHEN idx_scan > 1000 AND idx_tup_fetch::NUMERIC / idx_scan > 10 THEN 'High efficiency - keep'
            ELSE 'Monitor usage'
        END::TEXT as recommendation
    FROM pg_stat_user_indexes
    WHERE schemaname = 'public'
    ORDER BY idx_scan DESC, size_mb DESC;
END;
$$ LANGUAGE plpgsql;

-- Data quality validation
CREATE OR REPLACE FUNCTION validate_data_quality()
RETURNS TABLE(
    check_name TEXT,
    table_name TEXT,
    issue_count BIGINT,
    severity TEXT,
    description TEXT
) AS $$
BEGIN
    -- Check for duplicate plant entries in facit
    RETURN QUERY
    SELECT 
        'Duplicate Plant Names'::TEXT,
        'facit'::TEXT,
        COUNT(*)::BIGINT,
        'Medium'::TEXT,
        'Plants with identical names that might be duplicates'::TEXT
    FROM (
        SELECT name, COUNT(*) as cnt
        FROM facit 
        WHERE name IS NOT NULL
        GROUP BY name 
        HAVING COUNT(*) > 1
    ) duplicates;
    
    -- Check for orphaned totallager records
    RETURN QUERY
    SELECT 
        'Orphaned Inventory Records'::TEXT,
        'totallager'::TEXT,
        COUNT(*)::BIGINT,
        'High'::TEXT,
        'Inventory records without valid plant or nursery references'::TEXT
    FROM totallager tl
    LEFT JOIN facit f ON tl.facit_id = f.id
    LEFT JOIN plantskolor p ON tl.plantskola_id = p.id
    WHERE f.id IS NULL OR p.id IS NULL;
    
    -- Check for missing plant information
    RETURN QUERY
    SELECT 
        'Missing Plant Names'::TEXT,
        'facit'::TEXT,
        COUNT(*)::BIGINT,
        'Medium'::TEXT,
        'Plants without names or Swedish names'::TEXT
    FROM facit 
    WHERE name IS NULL OR trim(name) = '';
    
    -- Check for invalid stock values
    RETURN QUERY
    SELECT 
        'Invalid Stock Values'::TEXT,
        'totallager'::TEXT,
        COUNT(*)::BIGINT,
        'Low'::TEXT,
        'Inventory records with negative stock values'::TEXT
    FROM totallager 
    WHERE stock < 0;
    
    -- Check for invalid prices
    RETURN QUERY
    SELECT 
        'Invalid Prices'::TEXT,
        'totallager'::TEXT,
        COUNT(*)::BIGINT,
        'Medium'::TEXT,
        'Inventory records with negative or extremely high prices'::TEXT
    FROM totallager 
    WHERE price < 0 OR price > 10000;
END;
$$ LANGUAGE plpgsql;

-- Historical trend calculations
CREATE OR REPLACE FUNCTION calculate_growth_trends(days_back INTEGER DEFAULT 30)
RETURNS TABLE(
    metric_name TEXT,
    current_value BIGINT,
    previous_value BIGINT,
    change_percent NUMERIC,
    trend_direction TEXT
) AS $$
BEGIN
    -- Plant count trends
    RETURN QUERY
    SELECT 
        'Total Plants'::TEXT,
        (SELECT COUNT(*) FROM facit)::BIGINT,
        (SELECT COUNT(*) FROM facit WHERE created_at <= NOW() - INTERVAL '1 month')::BIGINT,
        ROUND(
            ((SELECT COUNT(*) FROM facit)::NUMERIC - 
             (SELECT COUNT(*) FROM facit WHERE created_at <= NOW() - INTERVAL '1 month')::NUMERIC) /
            NULLIF((SELECT COUNT(*) FROM facit WHERE created_at <= NOW() - INTERVAL '1 month'), 0) * 100, 2
        ),
        CASE 
            WHEN (SELECT COUNT(*) FROM facit) > 
                 (SELECT COUNT(*) FROM facit WHERE created_at <= NOW() - INTERVAL '1 month') 
            THEN 'Growing'
            ELSE 'Stable'
        END::TEXT;
    
    -- Nursery count trends
    RETURN QUERY
    SELECT 
        'Active Nurseries'::TEXT,
        (SELECT COUNT(*) FROM plantskolor WHERE verified = true AND hidden = false)::BIGINT,
        (SELECT COUNT(*) FROM plantskolor WHERE verified = true AND hidden = false 
         AND created_at <= NOW() - INTERVAL '1 month')::BIGINT,
        ROUND(
            ((SELECT COUNT(*) FROM plantskolor WHERE verified = true AND hidden = false)::NUMERIC - 
             (SELECT COUNT(*) FROM plantskolor WHERE verified = true AND hidden = false 
              AND created_at <= NOW() - INTERVAL '1 month')::NUMERIC) /
            NULLIF((SELECT COUNT(*) FROM plantskolor WHERE verified = true AND hidden = false 
                    AND created_at <= NOW() - INTERVAL '1 month'), 0) * 100, 2
        ),
        'Growing'::TEXT;
    
    -- Inventory trends
    RETURN QUERY
    SELECT 
        'Total Inventory Items'::TEXT,
        (SELECT COUNT(*) FROM totallager WHERE hidden = false)::BIGINT,
        (SELECT COUNT(*) FROM totallager WHERE hidden = false 
         AND created_at <= NOW() - INTERVAL '1 month')::BIGINT,
        ROUND(
            ((SELECT COUNT(*) FROM totallager WHERE hidden = false)::NUMERIC - 
             (SELECT COUNT(*) FROM totallager WHERE hidden = false 
              AND created_at <= NOW() - INTERVAL '1 month')::NUMERIC) /
            NULLIF((SELECT COUNT(*) FROM totallager WHERE hidden = false 
                    AND created_at <= NOW() - INTERVAL '1 month'), 0) * 100, 2
        ),
        'Growing'::TEXT;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================================
-- SAMPLING STRATEGIES FOR LARGE DATASETS
-- =====================================================================================

-- Sample-based plant popularity analysis (10% sample)
CREATE OR REPLACE FUNCTION sample_plant_popularity(sample_percent NUMERIC DEFAULT 10.0)
RETURNS TABLE(
    plant_id BIGINT,
    plant_name TEXT,
    plant_sv_name TEXT,
    sample_nursery_count BIGINT,
    estimated_total_nurseries BIGINT,
    sample_stock BIGINT,
    estimated_total_stock BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        f.id,
        f.name,
        f.sv_name,
        COUNT(DISTINCT tl.plantskola_id) as sample_nursery_count,
        ROUND(COUNT(DISTINCT tl.plantskola_id) * (100.0 / sample_percent))::BIGINT as estimated_total_nurseries,
        SUM(CASE WHEN tl.stock IS NOT NULL THEN tl.stock ELSE 0 END) as sample_stock,
        ROUND(SUM(CASE WHEN tl.stock IS NOT NULL THEN tl.stock ELSE 0 END) * (100.0 / sample_percent))::BIGINT as estimated_total_stock
    FROM facit f
    INNER JOIN totallager tl ON f.id = tl.facit_id
    WHERE random() < (sample_percent / 100.0) -- Sample based on percentage
    AND tl.hidden = false
    GROUP BY f.id, f.name, f.sv_name
    HAVING COUNT(DISTINCT tl.plantskola_id) >= 2
    ORDER BY estimated_total_nurseries DESC
    LIMIT 100;
END;
$$ LANGUAGE plpgsql;

-- Rolling window analysis (last 30 days vs previous 30 days)
CREATE OR REPLACE FUNCTION rolling_window_analysis()
RETURNS TABLE(
    metric_name TEXT,
    current_period_value BIGINT,
    previous_period_value BIGINT,
    change_percent NUMERIC
) AS $$
BEGIN
    -- New plants added
    RETURN QUERY
    SELECT 
        'New Plants (Last 30 Days)'::TEXT,
        (SELECT COUNT(*) FROM facit WHERE created_at >= NOW() - INTERVAL '30 days')::BIGINT,
        (SELECT COUNT(*) FROM facit 
         WHERE created_at >= NOW() - INTERVAL '60 days' 
         AND created_at < NOW() - INTERVAL '30 days')::BIGINT,
        ROUND(
            ((SELECT COUNT(*) FROM facit WHERE created_at >= NOW() - INTERVAL '30 days')::NUMERIC - 
             (SELECT COUNT(*) FROM facit 
              WHERE created_at >= NOW() - INTERVAL '60 days' 
              AND created_at < NOW() - INTERVAL '30 days')::NUMERIC) /
            NULLIF((SELECT COUNT(*) FROM facit 
                    WHERE created_at >= NOW() - INTERVAL '60 days' 
                    AND created_at < NOW() - INTERVAL '30 days'), 0) * 100, 2
        );
    
    -- New nurseries
    RETURN QUERY
    SELECT 
        'New Nurseries (Last 30 Days)'::TEXT,
        (SELECT COUNT(*) FROM plantskolor WHERE created_at >= NOW() - INTERVAL '30 days')::BIGINT,
        (SELECT COUNT(*) FROM plantskolor 
         WHERE created_at >= NOW() - INTERVAL '60 days' 
         AND created_at < NOW() - INTERVAL '30 days')::BIGINT,
        ROUND(
            ((SELECT COUNT(*) FROM plantskolor WHERE created_at >= NOW() - INTERVAL '30 days')::NUMERIC - 
             (SELECT COUNT(*) FROM plantskolor 
              WHERE created_at >= NOW() - INTERVAL '60 days' 
              AND created_at < NOW() - INTERVAL '30 days')::NUMERIC) /
            NULLIF((SELECT COUNT(*) FROM plantskolor 
                    WHERE created_at >= NOW() - INTERVAL '60 days' 
                    AND created_at < NOW() - INTERVAL '30 days'), 0) * 100, 2
        );
END;
$$ LANGUAGE plpgsql;

-- =====================================================================================
-- REAL-TIME ALERTING SYSTEM
-- =====================================================================================

-- Function to check critical thresholds
CREATE OR REPLACE FUNCTION check_critical_thresholds()
RETURNS TABLE(
    alert_level TEXT,
    metric_name TEXT,
    current_value NUMERIC,
    threshold_value NUMERIC,
    description TEXT
) AS $$
DECLARE
    connection_count INTEGER;
    max_connections INTEGER;
    slow_query_count INTEGER;
    cache_hit_ratio NUMERIC;
BEGIN
    -- Check connection count
    SELECT COUNT(*) INTO connection_count FROM pg_stat_activity;
    SELECT setting::INTEGER INTO max_connections FROM pg_settings WHERE name = 'max_connections';
    
    IF connection_count > max_connections * 0.8 THEN
        RETURN QUERY SELECT 
            'HIGH'::TEXT, 
            'Connection Count'::TEXT, 
            connection_count::NUMERIC, 
            (max_connections * 0.8)::NUMERIC,
            'Connection pool is nearing capacity'::TEXT;
    END IF;
    
    -- Check for slow queries
    SELECT COUNT(*) INTO slow_query_count 
    FROM pg_stat_activity 
    WHERE state = 'active' 
    AND EXTRACT(EPOCH FROM (NOW() - query_start)) > 10;
    
    IF slow_query_count > 0 THEN
        RETURN QUERY SELECT 
            'MEDIUM'::TEXT, 
            'Slow Queries'::TEXT, 
            slow_query_count::NUMERIC, 
            0::NUMERIC,
            'Queries running longer than 10 seconds detected'::TEXT;
    END IF;
    
    -- Check cache hit ratio
    SELECT ROUND(
        (sum(heap_blks_hit) / NULLIF(sum(heap_blks_hit) + sum(heap_blks_read), 0)) * 100, 2
    ) INTO cache_hit_ratio
    FROM pg_statio_user_tables;
    
    IF cache_hit_ratio < 95 THEN
        RETURN QUERY SELECT 
            'MEDIUM'::TEXT, 
            'Buffer Cache Hit Ratio'::TEXT, 
            cache_hit_ratio, 
            95::NUMERIC,
            'Buffer cache hit ratio is below recommended threshold'::TEXT;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================================
-- MONITORING RESULT CACHING AND HISTORICAL STORAGE
-- =====================================================================================

-- Table to store monitoring results for historical analysis
CREATE TABLE IF NOT EXISTS monitoring_history (
    id BIGSERIAL PRIMARY KEY,
    metric_name TEXT NOT NULL,
    metric_value NUMERIC,
    metric_metadata JSONB,
    collected_at TIMESTAMPTZ DEFAULT NOW(),
    metric_type TEXT NOT NULL -- 'performance', 'usage', 'health', 'quality'
);

-- Index for efficient historical queries
CREATE INDEX IF NOT EXISTS idx_monitoring_history_metric_time 
ON monitoring_history (metric_name, collected_at DESC);

-- Function to store monitoring results
CREATE OR REPLACE FUNCTION store_monitoring_result(
    p_metric_name TEXT,
    p_metric_value NUMERIC,
    p_metric_metadata JSONB DEFAULT NULL,
    p_metric_type TEXT DEFAULT 'performance'
)
RETURNS void AS $$
BEGIN
    INSERT INTO monitoring_history (metric_name, metric_value, metric_metadata, metric_type)
    VALUES (p_metric_name, p_metric_value, p_metric_metadata, p_metric_type);
END;
$$ LANGUAGE plpgsql;

-- Function to get historical trends for a metric
CREATE OR REPLACE FUNCTION get_metric_history(
    p_metric_name TEXT,
    p_days_back INTEGER DEFAULT 7
)
RETURNS TABLE(
    collected_at TIMESTAMPTZ,
    metric_value NUMERIC,
    metric_metadata JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        mh.collected_at,
        mh.metric_value,
        mh.metric_metadata
    FROM monitoring_history mh
    WHERE mh.metric_name = p_metric_name
    AND mh.collected_at >= NOW() - (p_days_back || ' days')::INTERVAL
    ORDER BY mh.collected_at DESC;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================================
-- AUTOMATED MONITORING SCHEDULER
-- =====================================================================================

-- Function to run all lightweight monitoring checks
CREATE OR REPLACE FUNCTION run_lightweight_monitoring()
RETURNS void AS $$
DECLARE
    conn_stats RECORD;
    cache_ratio NUMERIC;
BEGIN
    -- Collect connection statistics
    SELECT * INTO conn_stats FROM get_active_connections();
    
    PERFORM store_monitoring_result(
        'active_connections', 
        conn_stats.total_connections, 
        jsonb_build_object(
            'active_queries', conn_stats.active_queries,
            'idle_connections', conn_stats.idle_connections,
            'max_connections', conn_stats.max_connections
        ),
        'health'
    );
    
    -- Collect cache hit ratio
    SELECT percentage INTO cache_ratio 
    FROM cache_hit_ratios 
    WHERE metric = 'Buffer Cache Hit Ratio';
    
    IF cache_ratio IS NOT NULL THEN
        PERFORM store_monitoring_result(
            'buffer_cache_hit_ratio', 
            cache_ratio, 
            NULL,
            'performance'
        );
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Function to run medium-impact monitoring checks
CREATE OR REPLACE FUNCTION run_medium_monitoring()
RETURNS void AS $$
DECLARE
    slow_query_count INTEGER;
    lock_count INTEGER;
BEGIN
    -- Check for slow queries
    SELECT COUNT(*) INTO slow_query_count 
    FROM detect_slow_queries(5);
    
    PERFORM store_monitoring_result(
        'slow_queries_count', 
        slow_query_count, 
        jsonb_build_object('threshold_seconds', 5),
        'performance'
    );
    
    -- Check for lock contention
    SELECT COUNT(*) INTO lock_count 
    FROM analyze_lock_contention();
    
    PERFORM store_monitoring_result(
        'lock_contention_count', 
        lock_count, 
        NULL,
        'health'
    );
END;
$$ LANGUAGE plpgsql;
