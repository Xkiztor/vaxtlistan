-- =====================================================================================
-- Function: search_plants_main_page_strict(search_term, filters, include_hidden, result_limit, offset)
-- =====================================================================================
-- 
-- PURPOSE:
-- Strict search function for the main search page when using name/popularity sorting.
-- Uses exact matching instead of fuzzy search for faster performance and more
-- predictable results when users want to sort by name or popularity.
--
-- PARAMETERS:
-- - search_term: TEXT - The plant name to search for (exact matching)
-- - filters: JSONB - Advanced filter options (plant_type etc.)
-- - include_hidden: BOOLEAN - Whether to include hidden plants (default FALSE)
-- - sort_by: TEXT - Sort option (popularity, name_asc, name_desc)
-- - result_limit: INTEGER - Maximum number of results per page (default 20)
-- - offset: INTEGER - Pagination offset (default 0)
--
-- FILTER OPTIONS (JSONB format):
-- {
--   "plant_types": ["T", "S"]           // Plant type filter
-- }
--
-- RETURNS:
-- Same format as search_plants_main_page but uses strict matching instead of fuzzy search
--
-- MATCHING BEHAVIOR:
-- - Exact substring matching using ILIKE for performance
-- - Searches across plant name, Swedish name, grupp, and serie fields
-- - No similarity scoring (all matches get score 1.0)
-- - Faster execution than fuzzy search
-- - Better for alphabetical sorting and popularity-based sorting
--
-- =====================================================================================

DROP FUNCTION IF EXISTS search_plants_main_page_strict(TEXT, JSONB, BOOLEAN, INTEGER, INTEGER);
DROP FUNCTION IF EXISTS search_plants_main_page_strict(TEXT, JSONB, BOOLEAN, TEXT, INTEGER, INTEGER);

CREATE OR REPLACE FUNCTION search_plants_main_page_strict(
    search_term TEXT DEFAULT NULL,
    filters JSONB DEFAULT '{}',
    include_hidden BOOLEAN DEFAULT FALSE,
    sort_by TEXT DEFAULT 'popularity',
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
    total_results INTEGER,
    debug_sort_method TEXT
) AS $$
DECLARE
    v_sort_option TEXT := LOWER(COALESCE(sort_by, 'popularity'));
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
        -- Strict search term matching (no fuzzy search)
        (v_search_term_sanitized IS NULL OR (
            sanitize_plant_name(f.name) ILIKE '%' || v_search_term_sanitized || '%' OR
            sanitize_plant_name(COALESCE(f.sv_name, '')) ILIKE '%' || v_search_term_sanitized || '%' OR
            sanitize_plant_name(COALESCE(f.grupp, '')) ILIKE '%' || v_search_term_sanitized || '%' OR
            sanitize_plant_name(COALESCE(f.serie, '')) ILIKE '%' || v_search_term_sanitized || '%'
        ))
        -- Plant type filter
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
            f.popularity_score,
            -- Set similarity score to 1.0 for all strict matches
            1.0::FLOAT as similarity_score,
            f.height,
            f.spread,
            f.sunlight,
            f.colors,
            f.season_of_interest,
            f.images
        FROM facit f
        WHERE
            -- Strict search term matching (no fuzzy search)
            (v_search_term_sanitized IS NULL OR (
                sanitize_plant_name(f.name) ILIKE '%' || v_search_term_sanitized || '%' OR
                sanitize_plant_name(COALESCE(f.sv_name, '')) ILIKE '%' || v_search_term_sanitized || '%' OR
                sanitize_plant_name(COALESCE(f.grupp, '')) ILIKE '%' || v_search_term_sanitized || '%' OR
                sanitize_plant_name(COALESCE(f.serie, '')) ILIKE '%' || v_search_term_sanitized || '%'
            ))
            -- Plant type filter
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
            ps.popularity_score,
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
                    'nursery_address', p.postort
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
            AND (tl.stock > 0 OR tl.stock IS NULL)
        GROUP BY 
            ps.id, ps.name, ps.sv_name, ps.plant_type, ps.rhs_types, ps.taxonomy_type,
            ps.grupp, ps.serie, ps.similarity_score, ps.popularity_score, ps.height, ps.spread, 
            ps.sunlight, ps.colors, ps.season_of_interest, ps.images
    ),
    sorted_results AS (
        SELECT
            *,
            -- Create plant attributes JSONB
            jsonb_build_object(
                'height', height,
                'spread', spread,
                'sunlight', sunlight,
                'colors', colors,
                'season_interest', season_of_interest
            ) as plant_attributes,
            -- Debug: Show which sort method is being applied
            CASE 
                WHEN v_sort_option = 'name_asc' THEN 'name_asc'
                WHEN v_sort_option = 'name_desc' THEN 'name_desc'
                WHEN v_sort_option = 'popularity' THEN 'popularity'
                ELSE 'fallback_popularity'
            END as debug_sort_method
        FROM plant_aggregations
        ORDER BY
            CASE 
                WHEN v_sort_option = 'name_asc' THEN plant_aggregations.name
                WHEN v_sort_option = 'name_desc' THEN NULL
                ELSE NULL
            END ASC,
            CASE 
                WHEN v_sort_option = 'name_desc' THEN plant_aggregations.name
                ELSE NULL
            END DESC,
            CASE 
                WHEN v_sort_option = 'popularity' THEN plant_aggregations.popularity_score
                ELSE NULL
            END DESC,
            -- Always fall back to these for consistent ordering
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
        v_total_count as total_results,
        sr.debug_sort_method
    FROM sorted_results sr
    LIMIT result_limit OFFSET offset_param;
    
END;
$$ LANGUAGE plpgsql
SET client_encoding = 'UTF8';
