-- =====================================================================================
-- Function: search_plants_main_page(search_term, filters, include_hidden, result_limit, offset)
-- =====================================================================================
-- 
-- PURPOSE:
-- Comprehensive search function specifically designed for the main search page.
-- Provides detailed plant information with advanced filtering, sorting, and
-- pagination capabilities for in-depth plant discovery and comparison.
--
-- PARAMETERS:
-- - search_term: TEXT - The plant name to search for
-- - filters: JSONB - Advanced filter options (plant_type etc.)
-- - include_hidden: BOOLEAN - Whether to include hidden plants (default FALSE)
-- - result_limit: INTEGER - Maximum number of results per page (default 20)
-- - offset: INTEGER - Pagination offset (default 0)
--
-- FILTER OPTIONS (JSONB format):
-- {
--   "plant_types": ["T", "S"],           // Plant type filter
--   "sort_by": "relevance"              // relevance, price_asc, price_desc, name
-- }
--
-- RETURNS:
-- Table with comprehensive plant and availability data:
-- - id: BIGINT - Plant ID from facit table
-- - name: TEXT - Scientific plant name
-- - sv_name: TEXT - Swedish/common name
-- - plant_type: TEXT - Type classification
-- - rhs_types: SMALLINT[] - RHS type categories
-- - taxonomy_type: TEXT - Taxonomic classification
-- - similarity_score: FLOAT - Search relevance score
-- - available_count: INTEGER - Total plants available across all nurseries
-- - plantskolor_count: INTEGER - Number of nurseries with this plant in stock
-- - prices: JSONB - Array of price objects with nursery details
-- - min_price: NUMERIC - Cheapest available price
-- - max_price: NUMERIC - Most expensive available price
-- - avg_price: NUMERIC - Average price across nurseries
-- - nursery_info: JSONB - Aggregated nursery information
-- - plant_attributes: JSONB - Detailed plant characteristics
-- - total_results: INTEGER - Total matching results (for pagination)
--
-- NURSERY_INFO FORMAT:
-- {
--   "postorder_available": true,
--   "on_site_available": true,
--   "verified_nurseries": 5,
--   "total_nurseries": 7,
--   "geographic_distribution": ["Stockholm", "Göteborg", "Malmö"]
-- }
--
-- PLANT_ATTRIBUTES FORMAT:
-- {
--   "height": "8-12 meter",
--   "spread": "2.5-4 meter",
--   "sunlight": [1],
--   "colors": ["8-3-1", "11-3-1"],
--   "season_interest": [1,2,3,4]
-- }
--
-- ADVANCED FEATURES:
-- - Fuzzy search with high-quality similarity scoring
-- - Complex filtering by plant and nursery characteristics
-- - Advanced sorting options (relevance, price, name, availability)
-- - Pagination support for large result sets
-- - Detailed aggregation of pricing and availability data
-- - Geographic distribution of nurseries
-- - Comprehensive plant attribute information
--
-- PERFORMANCE CONSIDERATIONS:
-- - Materialized views for complex aggregations
-- - Proper indexing for filter combinations
-- - Query optimization for pagination
-- - Caching for popular filter combinations
-- - Limit complex calculations to displayed results only
--
-- TODO FOR AI IMPLEMENTATION:
-- 1. Implement comprehensive plant search with fuzzy matching
-- 2. Add complex filtering logic based on JSONB filters parameter
-- 3. Create detailed price and availability aggregations
-- 4. Implement multiple sorting options (relevance, price, name)
-- 5. Add pagination support with total count
-- 6. Include comprehensive plant attribute information
-- 7. Aggregate nursery distribution and characteristics
-- 8. Optimize performance for complex filter combinations
-- 9. Add result caching for popular searches
-- 10. Include search analytics and logging
-- 11. Handle edge cases and validation
-- 12. Add geographic and seasonal filtering
-- =====================================================================================

-- =====================================================================================
-- Function: search_plants_main_page
-- Comprehensive search function for the main search page
-- =====================================================================================

-- =====================================================================================
-- Function: search_plants_main_page
-- Comprehensive search function for the main search page
-- =====================================================================================

CREATE OR REPLACE FUNCTION search_plants_main_page(
    search_term TEXT DEFAULT NULL,
    filters JSONB DEFAULT '{}',
    include_hidden BOOLEAN DEFAULT FALSE,
    result_limit INTEGER DEFAULT 20,
    offset_param INTEGER DEFAULT 0
)
RETURNS TABLE(
    id BIGINT,
    name TEXT,
    sv_name TEXT,
    plant_type TEXT,
    rhs_types SMALLINT[],
    taxonomy_type TEXT,
    similarity_score FLOAT,
    available_count INTEGER,
    plantskolor_count INTEGER,
    prices JSONB,
    min_price NUMERIC,
    max_price NUMERIC,
    avg_price NUMERIC,
    nursery_info JSONB,
    plant_attributes JSONB,
    total_results INTEGER
) AS $$
DECLARE
    v_sort_option TEXT := COALESCE(filters->>'sort_by', 'relevance');
    v_plant_type_filter TEXT[] := NULL;
    v_total_count INTEGER;
    v_search_term_sanitized TEXT;
BEGIN
    -- Sanitize search term if provided
    IF search_term IS NOT NULL AND trim(search_term) != '' THEN
        v_search_term_sanitized := sanitize_plant_name(search_term);
    END IF;
    
    -- Extract plant type filter from JSONB
    IF filters ? 'plant_types' THEN
        SELECT ARRAY(SELECT jsonb_array_elements_text(filters->'plant_types')) INTO v_plant_type_filter;
    END IF;
      -- Get total count for pagination
    SELECT COUNT(DISTINCT f.id) INTO v_total_count
    FROM facit f
    LEFT JOIN totallager tl ON f.id = tl.facit_id
    LEFT JOIN plantskolor p ON tl.plantskola_id = p.id
    WHERE 
        -- Search term matching
        (v_search_term_sanitized IS NULL OR (
            similarity(sanitize_plant_name(f.name), v_search_term_sanitized) > 0.3 OR
            similarity(sanitize_plant_name(COALESCE(f.sv_name, '')), v_search_term_sanitized) > 0.3 OR
            sanitize_plant_name(f.name) ILIKE '%' || v_search_term_sanitized || '%' OR
            sanitize_plant_name(COALESCE(f.sv_name, '')) ILIKE '%' || v_search_term_sanitized || '%'
        ))
        -- Plant type filter (only filter available)
        AND (v_plant_type_filter IS NULL OR f.plant_type = ANY(v_plant_type_filter))
        -- Only show plants with some availability
        AND EXISTS (
            SELECT 1 FROM totallager tl2
            INNER JOIN plantskolor p2 ON tl2.plantskola_id = p2.id
            WHERE tl2.facit_id = f.id
            AND tl2.hidden = false
            AND p2.hidden = false
            AND p2.verified = true
            AND (tl2.stock > 0 OR tl2.stock IS NULL)
        );
    
    -- Main search query with aggregations
    RETURN QUERY
    WITH plant_search AS (
        SELECT DISTINCT
            f.id,
            f.name,
            f.sv_name,
            f.plant_type,
            f.rhs_types,
            f.taxonomy_type,
            -- Calculate similarity score
            CASE 
                WHEN v_search_term_sanitized IS NULL THEN 1.0
                ELSE GREATEST(
                    similarity(sanitize_plant_name(f.name), v_search_term_sanitized),
                    similarity(sanitize_plant_name(COALESCE(f.sv_name, '')), v_search_term_sanitized),
                    CASE 
                        WHEN sanitize_plant_name(f.name) ILIKE v_search_term_sanitized || '%' THEN 0.9
                        WHEN sanitize_plant_name(f.name) ILIKE '%' || v_search_term_sanitized || '%' THEN 0.7
                        WHEN sanitize_plant_name(COALESCE(f.sv_name, '')) ILIKE v_search_term_sanitized || '%' THEN 0.9
                        WHEN sanitize_plant_name(COALESCE(f.sv_name, '')) ILIKE '%' || v_search_term_sanitized || '%' THEN 0.7
                        ELSE 0.0
                    END
                )
            END::FLOAT as similarity_score,            f.height,
            f.spread,
            f.sunlight,
            f.colors,            f.season_of_interest
        FROM facit f
        WHERE
            -- Search term matching
            (v_search_term_sanitized IS NULL OR (
                similarity(sanitize_plant_name(f.name), v_search_term_sanitized) > 0.3 OR
                similarity(sanitize_plant_name(COALESCE(f.sv_name, '')), v_search_term_sanitized) > 0.3 OR
                sanitize_plant_name(f.name) ILIKE '%' || v_search_term_sanitized || '%' OR
                sanitize_plant_name(COALESCE(f.sv_name, '')) ILIKE '%' || v_search_term_sanitized || '%'
            ))
            -- Plant type filter (only filter available)
            AND (v_plant_type_filter IS NULL OR f.plant_type = ANY(v_plant_type_filter))
            -- Only include plants that have availability
            AND EXISTS (
                SELECT 1 FROM totallager tl
                INNER JOIN plantskolor p ON tl.plantskola_id = p.id
                WHERE tl.facit_id = f.id
                AND tl.hidden = false
                AND p.hidden = false
                AND p.verified = true
                AND (tl.stock > 0 OR tl.stock IS NULL)
            )
    ),
    plant_aggregations AS (
        SELECT 
            ps.id,
            ps.name,
            ps.sv_name,
            ps.plant_type,
            ps.rhs_types,
            ps.taxonomy_type,
            ps.similarity_score,            ps.height,
            ps.spread,
            ps.sunlight,
            ps.colors,
            ps.season_of_interest,
            -- Availability aggregations
            SUM(CASE WHEN tl.stock IS NOT NULL THEN tl.stock ELSE 0 END)::INTEGER as available_count,
            COUNT(DISTINCT tl.plantskola_id)::INTEGER as plantskolor_count,
            -- Price aggregations
            MIN(tl.price) as min_price,
            MAX(tl.price) as max_price,
            ROUND(AVG(tl.price), 2) as avg_price,
            -- Price array with nursery details
            jsonb_agg(
                jsonb_build_object(
                    'price', tl.price,
                    'stock', tl.stock,
                    'pot', tl.pot,
                    'height', tl.height,
                    'nursery_id', p.id,
                    'nursery_name', p.name,
                    'postorder', p.postorder,
                    'on_site', p.on_site,
                    'nursery_address', p.adress
                ) ORDER BY tl.price ASC
            ) FILTER (WHERE tl.price IS NOT NULL) as prices,
            -- Nursery info aggregation
            jsonb_build_object(
                'postorder_available', BOOL_OR(p.postorder),
                'on_site_available', BOOL_OR(p.on_site),
                'verified_nurseries', COUNT(DISTINCT p.id),
                'total_nurseries', COUNT(DISTINCT p.id),
                'nursery_names', array_agg(DISTINCT p.name ORDER BY p.name)
            ) as nursery_info
        FROM plant_search ps
        INNER JOIN totallager tl ON ps.id = tl.facit_id
        INNER JOIN plantskolor p ON tl.plantskola_id = p.id
        WHERE 
            tl.hidden = false
            AND p.hidden = false
            AND p.verified = true
            AND (tl.stock > 0 OR tl.stock IS NULL)        GROUP BY 
            ps.id, ps.name, ps.sv_name, ps.plant_type, ps.rhs_types, ps.taxonomy_type,
            ps.similarity_score, ps.height, ps.spread, ps.sunlight, 
            ps.colors, ps.season_of_interest
    ),
    sorted_results AS (
        SELECT            *,
            -- Create plant attributes JSONB
            jsonb_build_object(                'height', height,
                'spread', spread,
                'sunlight', sunlight,
                'colors', colors,
                'season_interest', season_of_interest
            ) as plant_attributes
        FROM plant_aggregations
        ORDER BY
            CASE 
                WHEN v_sort_option = 'relevance' THEN plant_aggregations.similarity_score
                WHEN v_sort_option = 'price_asc' THEN plant_aggregations.min_price::FLOAT
                WHEN v_sort_option = 'price_desc' THEN -plant_aggregations.min_price::FLOAT
                WHEN v_sort_option = 'name' THEN 0
                ELSE plant_aggregations.similarity_score
            END DESC,
            CASE 
                WHEN v_sort_option = 'name' THEN plant_aggregations.name
                ELSE NULL
            END ASC,
            plant_aggregations.plantskolor_count DESC,
            plant_aggregations.available_count DESC
    )
    SELECT 
        sr.id,
        sr.name,
        sr.sv_name,
        sr.plant_type,
        sr.rhs_types,
        sr.taxonomy_type,
        sr.similarity_score,
        sr.available_count,
        sr.plantskolor_count,
        sr.prices,
        sr.min_price,
        sr.max_price,
        sr.avg_price,
        sr.nursery_info,
        sr.plant_attributes,
        v_total_count as total_results    FROM sorted_results sr
    LIMIT result_limit OFFSET offset_param;
    
END;
$$ LANGUAGE plpgsql
SET client_encoding = 'UTF8';

-- =====================================================================================
-- Search analytics logging function
-- =====================================================================================

CREATE TABLE IF NOT EXISTS search_analytics (
    id BIGSERIAL PRIMARY KEY,
    search_term TEXT,
    filters JSONB,
    result_count INTEGER,
    execution_time_ms NUMERIC,
    user_session TEXT,
    search_timestamp TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_search_analytics_timestamp ON search_analytics (search_timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_search_analytics_term ON search_analytics USING gin(to_tsvector('swedish', search_term)) WHERE search_term IS NOT NULL;

CREATE OR REPLACE FUNCTION log_search_analytics(
    p_search_term TEXT,
    p_filters JSONB,
    p_result_count INTEGER,
    p_execution_time_ms NUMERIC,
    p_user_session TEXT DEFAULT NULL
)
RETURNS void AS $$
BEGIN    INSERT INTO search_analytics (search_term, filters, result_count, execution_time_ms, user_session)
    VALUES (p_search_term, p_filters, p_result_count, p_execution_time_ms, p_user_session);
END;
$$ LANGUAGE plpgsql
SET client_encoding = 'UTF8';

-- =====================================================================================
-- Wrapper function with analytics logging
-- =====================================================================================

CREATE OR REPLACE FUNCTION search_plants_main_page_with_analytics(
    search_term TEXT DEFAULT NULL,
    filters JSONB DEFAULT '{}',
    include_hidden BOOLEAN DEFAULT FALSE,
    result_limit INTEGER DEFAULT 20,
    offset_param INTEGER DEFAULT 0,
    user_session TEXT DEFAULT NULL
)
RETURNS TABLE(
    id BIGINT,
    name TEXT,
    sv_name TEXT,
    plant_type TEXT,
    rhs_types SMALLINT[],
    taxonomy_type TEXT,
    similarity_score FLOAT,
    available_count INTEGER,
    plantskolor_count INTEGER,
    prices JSONB,
    min_price NUMERIC,
    max_price NUMERIC,
    avg_price NUMERIC,
    nursery_info JSONB,
    plant_attributes JSONB,
    total_results INTEGER
) AS $$
DECLARE
    start_time TIMESTAMP;
    end_time TIMESTAMP;
    execution_time_ms NUMERIC;
    result_count INTEGER := 0;
BEGIN
    start_time := clock_timestamp();
    
    -- Execute main search and return results
    RETURN QUERY
    SELECT * FROM search_plants_main_page(search_term, filters, include_hidden, result_limit, offset_param);
    
    -- Get result count from the first row
    GET DIAGNOSTICS result_count = ROW_COUNT;
    
    end_time := clock_timestamp();
    execution_time_ms := EXTRACT(EPOCH FROM (end_time - start_time)) * 1000;
    
    -- Log analytics (in background, don't fail if this errors)
    BEGIN
        PERFORM log_search_analytics(search_term, filters, result_count, execution_time_ms, user_session);    EXCEPTION
        WHEN OTHERS THEN
            -- Silently ignore analytics logging errors
            NULL;
    END;
    
END;
$$ LANGUAGE plpgsql
SET client_encoding = 'UTF8';
