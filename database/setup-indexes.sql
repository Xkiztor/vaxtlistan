-- =====================================================================================
-- Database Setup and Indexes
-- =====================================================================================
-- 
-- PURPOSE:
-- Creates all necessary indexes, extensions, and optimizations for the plant search
-- and inventory management system. This file should be run during database setup
-- to ensure optimal performance for all search functions.
--
-- REQUIRED EXTENSIONS:
-- - pg_trgm: For trigram similarity matching in fuzzy search
-- - unaccent: For handling accented characters in plant names
-- - btree_gin: For composite indexes combining different data types
--
-- PERFORMANCE INDEXES:
-- The following indexes are critical for search performance:
--
-- 1. Basic lookup indexes for foreign keys and primary operations
-- 2. Text search indexes for plant name searching
-- 3. Composite indexes for complex queries
-- 4. Partial indexes for filtered queries
-- 5. GIN indexes for JSONB and array operations
--
-- FACIT TABLE INDEXES:
-- - Primary search: name, sv_name, has_synonyms columns
-- - Filtering: synonym_to, user_submitted, plant_type
-- - Trigram indexes for fuzzy search performance
-- - Composite indexes for common query patterns
--
-- TOTALLAGER TABLE INDEXES:
-- - Foreign keys: facit_id, plantskola_id
-- - Filtering: hidden
-- - Composite indexes for availability queries
-- - JSONB indexes for custom fields (own_columns)
--
-- PLANTSKOLOR TABLE INDEXES:
-- - Basic lookups: user_id, verified status
-- - Text search: name, description
-- - Filtering: hidden, verified, postorder, on_site
--
-- MAINTENANCE CONSIDERATIONS:
-- - Analyze table statistics regularly
-- - Monitor index usage with pg_stat_user_indexes
-- - Consider index maintenance during low-traffic periods
-- - Vacuum and reindex on schedule
--
-- TODO FOR AI IMPLEMENTATION:
-- 1. Enable required PostgreSQL extensions
-- 2. Create all primary and foreign key indexes
-- 3. Add trigram indexes for fuzzy text search
-- 4. Create composite indexes for common query patterns
-- 5. Add partial indexes for filtered queries
-- 6. Create GIN indexes for JSONB and array fields
-- 7. Add proper statistics targets for query planning
-- 8. Include index creation timing and dependency order
-- 9. Add index monitoring and maintenance queries
-- 10. Document index usage patterns and recommendations
-- =====================================================================================

-- =====================================================================================
-- Database Setup and Indexes
-- =====================================================================================

-- =====================================================================================
-- REQUIRED EXTENSIONS
-- =====================================================================================

-- Enable required PostgreSQL extensions
CREATE EXTENSION IF NOT EXISTS pg_trgm;     -- For trigram similarity matching
CREATE EXTENSION IF NOT EXISTS unaccent;   -- For handling accented characters (optional)
CREATE EXTENSION IF NOT EXISTS btree_gin;  -- For composite GIN indexes

-- =====================================================================================
-- FACIT TABLE INDEXES
-- Only indexes for actually searched fields
-- =====================================================================================

-- Primary search indexes for plant names (most critical)
CREATE INDEX IF NOT EXISTS idx_facit_name_trgm 
ON facit USING gin (name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_facit_sv_name_trgm 
ON facit USING gin (sv_name gin_trgm_ops) 
WHERE sv_name IS NOT NULL;

-- Combined full-text search for both name columns (main search functionality)
CREATE INDEX IF NOT EXISTS idx_facit_combined_fts 
ON facit USING gin (to_tsvector('swedish', name || ' ' || COALESCE(sv_name, '')));

-- Plant type filtering (used in search filters)
CREATE INDEX IF NOT EXISTS idx_facit_plant_type 
ON facit (plant_type) 
WHERE plant_type IS NOT NULL;

-- Synonym handling (for search result expansion)
CREATE INDEX IF NOT EXISTS idx_facit_is_synonym 
ON facit (is_synonym) 
WHERE is_synonym = true;

CREATE INDEX IF NOT EXISTS idx_facit_synonym_to_id 
ON facit (synonym_to_id) 
WHERE synonym_to_id IS NOT NULL;

-- Composite index for main search queries (name + type + synonym status)
CREATE INDEX IF NOT EXISTS idx_facit_search_core 
ON facit (name, plant_type, is_synonym);

-- =====================================================================================
-- TOTALLAGER TABLE INDEXES
-- Essential indexes for inventory and availability queries
-- =====================================================================================

-- Foreign key indexes (critical for JOINs)
CREATE INDEX IF NOT EXISTS idx_totallager_facit_id 
ON totallager (facit_id);

CREATE INDEX IF NOT EXISTS idx_totallager_plantskola_id 
ON totallager (plantskola_id);

-- Visibility filtering (essential for showing only available plants)
CREATE INDEX IF NOT EXISTS idx_totallager_hidden 
ON totallager (hidden);

-- Stock filtering (for availability checks)
CREATE INDEX IF NOT EXISTS idx_totallager_stock 
ON totallager (stock) 
WHERE stock IS NOT NULL AND stock > 0;

-- Price filtering and sorting (commonly used in search)
CREATE INDEX IF NOT EXISTS idx_totallager_price 
ON totallager (price) 
WHERE price IS NOT NULL;

-- Composite index for main availability queries
CREATE INDEX IF NOT EXISTS idx_totallager_available 
ON totallager (facit_id, plantskola_id, hidden, stock) 
WHERE hidden = false;

-- Composite index for plant availability with price (complete search results)
CREATE INDEX IF NOT EXISTS idx_totallager_search_results 
ON totallager (facit_id, hidden, stock, price) 
WHERE hidden = false;

-- =====================================================================================
-- PLANTSKOLOR TABLE INDEXES
-- Essential indexes for nursery lookups and filtering
-- =====================================================================================

-- User relationship index (for admin access)
CREATE INDEX IF NOT EXISTS idx_plantskolor_user_id 
ON plantskolor (user_id) 
WHERE user_id IS NOT NULL;

-- Status filtering (critical for showing only active nurseries)
CREATE INDEX IF NOT EXISTS idx_plantskolor_verified 
ON plantskolor (verified);

CREATE INDEX IF NOT EXISTS idx_plantskolor_hidden 
ON plantskolor (hidden);

-- Composite index for active nurseries (most common filter)
CREATE INDEX IF NOT EXISTS idx_plantskolor_active 
ON plantskolor (verified, hidden) 
WHERE verified = true AND hidden = false;

-- Text search for nursery names (used in nursery search)
CREATE INDEX IF NOT EXISTS idx_plantskolor_name_trgm 
ON plantskolor USING gin (name gin_trgm_ops);

-- =====================================================================================
-- SUPERADMINS TABLE INDEXES
-- =====================================================================================

-- User relationship index (simple lookup table, minimal indexing needed)
CREATE INDEX IF NOT EXISTS idx_superadmins_user_id 
ON superadmins (user_id);

-- =====================================================================================
-- STATISTICS TARGETS FOR QUERY PLANNING
-- =====================================================================================

-- Increase statistics targets only for heavily searched columns
ALTER TABLE facit ALTER COLUMN name SET STATISTICS 1000;
ALTER TABLE facit ALTER COLUMN sv_name SET STATISTICS 1000;
ALTER TABLE facit ALTER COLUMN plant_type SET STATISTICS 500;
ALTER TABLE totallager ALTER COLUMN facit_id SET STATISTICS 1000;
ALTER TABLE totallager ALTER COLUMN plantskola_id SET STATISTICS 500;

-- =====================================================================================
-- INDEX MAINTENANCE AND MONITORING
-- =====================================================================================

-- Function to analyze index usage
CREATE OR REPLACE FUNCTION analyze_index_usage()
RETURNS TABLE(
    schema_name TEXT,
    table_name TEXT,
    index_name TEXT,
    index_scans BIGINT,
    tuples_read BIGINT,
    tuples_fetched BIGINT,
    size_mb NUMERIC
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
        ROUND(pg_relation_size(indexrelname::regclass) / 1024.0 / 1024.0, 2) as size_mb
    FROM pg_stat_user_indexes
    WHERE schemaname = 'public'
    ORDER BY idx_scan DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to identify unused indexes
CREATE OR REPLACE FUNCTION find_unused_indexes()
RETURNS TABLE(
    schema_name TEXT,
    table_name TEXT,
    index_name TEXT,
    size_mb NUMERIC,
    definition TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        schemaname::TEXT,
        tablename::TEXT,
        indexname::TEXT,
        ROUND(pg_relation_size(indexrelname::regclass) / 1024.0 / 1024.0, 2) as size_mb,
        pg_get_indexdef(i.indexrelid) as definition
    FROM pg_stat_user_indexes s
    JOIN pg_index i ON s.indexrelid = i.indexrelid
    WHERE schemaname = 'public'
    AND idx_scan = 0
    AND NOT i.indisunique  -- Don't include unique indexes (often used for constraints)
    ORDER BY pg_relation_size(indexrelname::regclass) DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to get index size summary
CREATE OR REPLACE FUNCTION index_size_summary()
RETURNS TABLE(
    table_name TEXT,
    total_indexes INTEGER,
    total_size_mb NUMERIC,
    largest_index TEXT,
    largest_size_mb NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    WITH index_sizes AS (
        SELECT 
            tablename,
            indexname,
            pg_relation_size(indexrelname::regclass) as size_bytes
        FROM pg_stat_user_indexes
        WHERE schemaname = 'public'
    ),
    table_summaries AS (
        SELECT 
            tablename,
            COUNT(*) as index_count,
            SUM(size_bytes) as total_bytes,
            MAX(size_bytes) as max_bytes
        FROM index_sizes
        GROUP BY tablename
    ),
    largest_per_table AS (
        SELECT DISTINCT ON (i.tablename)
            i.tablename,
            i.indexname,
            i.size_bytes
        FROM index_sizes i
        INNER JOIN table_summaries ts ON i.tablename = ts.tablename
        WHERE i.size_bytes = ts.max_bytes
        ORDER BY i.tablename, i.size_bytes DESC
    )
    SELECT 
        ts.tablename::TEXT,
        ts.index_count::INTEGER,
        ROUND(ts.total_bytes / 1024.0 / 1024.0, 2)::NUMERIC,
        lpt.indexname::TEXT,
        ROUND(lpt.size_bytes / 1024.0 / 1024.0, 2)::NUMERIC
    FROM table_summaries ts
    LEFT JOIN largest_per_table lpt ON ts.tablename = lpt.tablename
    ORDER BY ts.total_bytes DESC;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================================
-- MAINTENANCE COMMANDS
-- =====================================================================================

-- Command to update table statistics (run after significant data changes)
CREATE OR REPLACE FUNCTION update_table_statistics()
RETURNS void AS $$
BEGIN
    ANALYZE facit;
    ANALYZE totallager;
    ANALYZE plantskolor;
    ANALYZE superadmins;
    
    RAISE NOTICE 'Table statistics updated successfully';
END;
$$ LANGUAGE plpgsql;

-- Command to reindex all tables (run during maintenance windows)
CREATE OR REPLACE FUNCTION reindex_all_tables()
RETURNS void AS $$
BEGIN
    REINDEX TABLE facit;
    REINDEX TABLE totallager;
    REINDEX TABLE plantskolor;
    REINDEX TABLE superadmins;
    
    RAISE NOTICE 'All tables reindexed successfully';
END;
$$ LANGUAGE plpgsql;

-- =====================================================================================
-- INDEX CREATION VALIDATION
-- =====================================================================================

-- Verify that all critical indexes were created successfully
DO $$
DECLARE
    critical_indexes TEXT[] := ARRAY[
        'idx_facit_name_trgm',
        'idx_facit_combined_fts',
        'idx_facit_plant_type',
        'idx_totallager_facit_id',
        'idx_totallager_plantskola_id',
        'idx_totallager_available',
        'idx_plantskolor_active'
    ];
    index_name TEXT;
    index_exists BOOLEAN;
BEGIN
    FOREACH index_name IN ARRAY critical_indexes
    LOOP
        SELECT EXISTS (
            SELECT 1 FROM pg_indexes 
            WHERE schemaname = 'public' 
            AND indexname = index_name
        ) INTO index_exists;
        
        IF NOT index_exists THEN
            RAISE WARNING 'Critical index % was not created successfully', index_name;
        ELSE
            RAISE NOTICE 'Critical index % created successfully', index_name;
        END IF;
    END LOOP;
    
    RAISE NOTICE 'Index validation completed - only essential search indexes created';
END;
$$;
