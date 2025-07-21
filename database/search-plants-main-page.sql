-- =====================================================================================
-- Function: search_plants_main_page(search_term, filters, include_hidden, result_limit, offset)
-- =====================================================================================
-- 
-- PURPOSE:
-- Comprehensive search function specifically designed for the main search page.
-- Provides detailed plant information with advanced filtering, sorting, and
-- pagination capabilities for in-depth plant discovery and comparison.
-- Searches across plant name, Swedish name, grupp, and serie fields for comprehensive results.
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
--   "plant_types": ["T", "S"]           // Plant type filter
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
-- - grupp: TEXT - Plant group classification
-- - serie: TEXT - Plant series classification
-- - similarity_score: FLOAT - Search relevance score
-- - available_count: INTEGER - Total plants available across all nurseries
-- - plantskolor_count: INTEGER - Number of nurseries with this plant in stock
-- - prices: JSONB - Array of price objects with nursery details
-- - min_price: NUMERIC - Cheapest available price
-- - max_price: NUMERIC - Most expensive available price
-- - avg_price: NUMERIC - Average price across nurseries
-- - nursery_info: JSONB - Aggregated nursery information
-- - plant_attributes: JSONB - Detailed plant characteristics
-- - images: JSONB - Array of plant images
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
-- - Always sorted by relevance (similarity score)
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
-- 4. Always sort by relevance (similarity score)
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

DROP FUNCTION IF EXISTS search_plants_main_page(TEXT, JSONB, BOOLEAN, INTEGER, INTEGER );

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
    grupp TEXT,
    serie TEXT,
    similarity_score FLOAT,
    available_count INTEGER,
    plantskolor_count INTEGER,
    prices JSONB,
    min_price NUMERIC,
    max_price NUMERIC,
    avg_price NUMERIC,
    nursery_info JSONB,
    plant_attributes JSONB,
    images JSONB,
    total_results INTEGER
) AS $$
DECLARE
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
            similarity(sanitize_plant_name(COALESCE(f.grupp, '')), v_search_term_sanitized) > 0.3 OR
            similarity(sanitize_plant_name(COALESCE(f.serie, '')), v_search_term_sanitized) > 0.3 OR
            sanitize_plant_name(f.name) ILIKE '%' || v_search_term_sanitized || '%' OR
            sanitize_plant_name(COALESCE(f.sv_name, '')) ILIKE '%' || v_search_term_sanitized || '%' OR
            sanitize_plant_name(COALESCE(f.grupp, '')) ILIKE '%' || v_search_term_sanitized || '%' OR
            sanitize_plant_name(COALESCE(f.serie, '')) ILIKE '%' || v_search_term_sanitized || '%'
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
            f.grupp,
            f.serie,
            f.popularity_score, -- Include popularity score
            -- Calculate similarity score
            CASE 
                WHEN v_search_term_sanitized IS NULL THEN 1.0
                ELSE GREATEST(
                    similarity(sanitize_plant_name(f.name), v_search_term_sanitized),
                    similarity(sanitize_plant_name(COALESCE(f.sv_name, '')), v_search_term_sanitized),
                    similarity(sanitize_plant_name(COALESCE(f.grupp, '')), v_search_term_sanitized),
                    similarity(sanitize_plant_name(COALESCE(f.serie, '')), v_search_term_sanitized),
                    CASE 
                        WHEN sanitize_plant_name(f.name) ILIKE v_search_term_sanitized || '%' THEN 0.9
                        WHEN sanitize_plant_name(f.name) ILIKE '%' || v_search_term_sanitized || '%' THEN 0.7
                        WHEN sanitize_plant_name(COALESCE(f.sv_name, '')) ILIKE v_search_term_sanitized || '%' THEN 0.9
                        WHEN sanitize_plant_name(COALESCE(f.sv_name, '')) ILIKE '%' || v_search_term_sanitized || '%' THEN 0.7
                        WHEN sanitize_plant_name(COALESCE(f.grupp, '')) ILIKE v_search_term_sanitized || '%' THEN 0.8
                        WHEN sanitize_plant_name(COALESCE(f.grupp, '')) ILIKE '%' || v_search_term_sanitized || '%' THEN 0.6
                        WHEN sanitize_plant_name(COALESCE(f.serie, '')) ILIKE v_search_term_sanitized || '%' THEN 0.8
                        WHEN sanitize_plant_name(COALESCE(f.serie, '')) ILIKE '%' || v_search_term_sanitized || '%' THEN 0.6
                        ELSE 0.0
                    END
                )
            END::FLOAT as similarity_score,            f.height,
            f.spread,
            f.sunlight,
            f.colors,            f.season_of_interest,
            f.images
        FROM facit f
        WHERE
            -- Search term matching
            (v_search_term_sanitized IS NULL OR (
                similarity(sanitize_plant_name(f.name), v_search_term_sanitized) > 0.3 OR
                similarity(sanitize_plant_name(COALESCE(f.sv_name, '')), v_search_term_sanitized) > 0.3 OR
                similarity(sanitize_plant_name(COALESCE(f.grupp, '')), v_search_term_sanitized) > 0.3 OR
                similarity(sanitize_plant_name(COALESCE(f.serie, '')), v_search_term_sanitized) > 0.3 OR
                sanitize_plant_name(f.name) ILIKE '%' || v_search_term_sanitized || '%' OR
                sanitize_plant_name(COALESCE(f.sv_name, '')) ILIKE '%' || v_search_term_sanitized || '%' OR
                sanitize_plant_name(COALESCE(f.grupp, '')) ILIKE '%' || v_search_term_sanitized || '%' OR
                sanitize_plant_name(COALESCE(f.serie, '')) ILIKE '%' || v_search_term_sanitized || '%'
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
            ps.grupp,
            ps.serie,
            ps.similarity_score,
            ps.popularity_score, -- Include popularity score in aggregations
            ps.height,
            ps.spread,
            ps.sunlight,
            ps.colors,
            ps.season_of_interest,
            ps.images,
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
            ps.grupp, ps.serie, ps.similarity_score, ps.popularity_score, ps.height, ps.spread, 
            ps.sunlight, ps.colors, ps.season_of_interest, ps.images
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
            -- Always sort by relevance (similarity score) in fuzzy search
            plant_aggregations.similarity_score DESC,
            plant_aggregations.popularity_score DESC,
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
        sr.grupp,
        sr.serie,
        sr.similarity_score,
        sr.available_count,
        sr.plantskolor_count,
        sr.prices,
        sr.min_price,
        sr.max_price,
        sr.avg_price,
        sr.nursery_info,
        sr.plant_attributes,
        sr.images,
        v_total_count as total_results
    FROM sorted_results sr
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