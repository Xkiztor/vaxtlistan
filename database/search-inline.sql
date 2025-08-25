-- =====================================================================================
-- Function: search_inline(search_term, result_limit)
-- =====================================================================================
-- 
-- PURPOSE:
-- Fast inline search function for autocomplete and quick search components.
-- Searches both available plants AND plantskolor (nurseries) to provide
-- comprehensive results for user navigation and discovery.
--
-- PARAMETERS:
-- - search_term: TEXT - The search term to match against plants and nurseries
-- - result_limit: INTEGER - Maximum number of results per category (default 10)
--
-- RETURNS:
-- Table with unified search results:
-- - result_type: TEXT - 'plant' or 'plantskola' to distinguish result types
-- - id: BIGINT - ID from respective table (facit.id or plantskolor.id)
-- - name: TEXT - Display name (plant name or nursery name)
-- - secondary_name: TEXT - Secondary info (sv_name for plants, address for nurseries)
-- - plant_type: TEXT - Plant type (NULL for plantskolor results)
-- - similarity_score: FLOAT - Search relevance score
-- - metadata: JSONB - Additional context info
--
-- SEARCH BEHAVIOR:
-- - Fast prefix and contains matching (not fuzzy for performance)
-- - Case and special character insensitive using sanitize_plant_name()
-- - Searches plants: name, sv_name, has_synonyms
-- - Searches plantskolor: name, description
-- - Only includes verified, non-hidden nurseries
-- - Results ordered by relevance within each category
--
-- METADATA FORMAT:
-- For plants:
-- {
--   "available_count": 45,
--   "plantskolor_count": 3,
--   "min_price": 149.50,
-- }
--
-- For plantskolor:
-- {
--   "plant_count": 156,
--   "verified": true,
--   "postorder": true,
--   "on_site": true,
--   "phone": "+46123456789"
-- }
--
-- PERFORMANCE OPTIMIZATION:
-- - Lightweight queries for fast autocomplete response
-- - Basic aggregation only (no complex price arrays)
-- - Indexes on sanitized names for optimal performance
-- - Result limit to prevent large result sets
-- - Simple pattern matching over complex similarity
--
-- USE CASES:
-- - Header search autocomplete
-- - Quick navigation suggestions
-- - Mobile search interface
-- - Plant picker with nursery context
-- - Universal search across platform
--
-- EXAMPLE USAGE:
-- SELECT * FROM search_inline('rose', 5);
-- SELECT * FROM search_inline('plantagen', 10);
-- SELECT * FROM search_inline('pinus', 8);
--
-- TODO FOR AI IMPLEMENTATION:
-- 1. Create UNION query combining plant and plantskola searches
-- 2. Use sanitize_plant_name() for search term normalization
-- 3. Implement fast prefix and contains matching with ILIKE
-- 4. Add basic aggregation for plant availability metrics
-- 5. Include nursery metadata (plant count, contact info)
-- 6. Filter for verified nurseries
-- 7. Order results by relevance score within each category
-- 8. Apply result limits per category (not total)
-- 9. Optimize for sub-100ms response time
-- 10. Add proper error handling for edge cases
-- 11. Consider caching frequent search terms
-- 12. Add search analytics tracking
-- =====================================================================================

-- =====================================================================================
-- Function: search_inline
-- Fast inline search for autocomplete and quick search components
-- =====================================================================================

CREATE OR REPLACE FUNCTION search_inline(
    search_term TEXT,
    result_limit INTEGER DEFAULT 10
)
RETURNS TABLE(
    result_type TEXT,
    id BIGINT,
    name TEXT,
    secondary_name TEXT,
    plant_type TEXT,
    similarity_score FLOAT,
    metadata JSONB
) AS $$
DECLARE
    search_term_sanitized TEXT;
BEGIN
    -- Sanitize search term for consistent matching
    IF search_term IS NULL OR trim(search_term) = '' THEN
        RETURN;
    END IF;
    
    search_term_sanitized := sanitize_plant_name(search_term);
    
    -- Return empty if sanitized term is too short
    IF length(search_term_sanitized) < 2 THEN
        RETURN;
    END IF;
    
    RETURN QUERY
    (
        -- Search plants with availability data
        WITH plant_results AS (
            SELECT 
                'plant'::TEXT as result_type,
                f.id,
                f.name,
                f.sv_name as secondary_name,
                f.plant_type,
                -- Calculate relevance score based on match type
                CASE 
                    WHEN sanitize_plant_name(f.name) ILIKE search_term_sanitized || '%' THEN 1.0
                    WHEN sanitize_plant_name(COALESCE(f.sv_name, '')) ILIKE search_term_sanitized || '%' THEN 0.9
                    WHEN sanitize_plant_name(f.name) ILIKE '%' || search_term_sanitized || '%' THEN 0.8
                    WHEN sanitize_plant_name(COALESCE(f.sv_name, '')) ILIKE '%' || search_term_sanitized || '%' THEN 0.7
                    WHEN sanitize_plant_name(COALESCE(f.has_synonyms, '')) ILIKE '%' || search_term_sanitized || '%' THEN 0.6
                    ELSE 0.5
                END::FLOAT as similarity_score
            FROM facit f
            WHERE 
                (
                    sanitize_plant_name(f.name) ILIKE '%' || search_term_sanitized || '%' OR
                    sanitize_plant_name(COALESCE(f.sv_name, '')) ILIKE '%' || search_term_sanitized || '%' OR
                    sanitize_plant_name(COALESCE(f.has_synonyms, '')) ILIKE '%' || search_term_sanitized || '%'
                )
                -- Only include plants with availability
                AND EXISTS (
                    SELECT 1 FROM totallager tl
                    INNER JOIN plantskolor p ON tl.plantskola_id = p.id
                    WHERE tl.facit_id = f.id
                    AND tl.hidden = false
                    AND p.hidden = false
                    AND p.verified = true
                    AND (tl.stock > 0 OR tl.stock IS NULL)
                )
            ORDER BY similarity_score DESC, f.name ASC
            LIMIT result_limit
        ),
        plant_metadata AS (
            SELECT 
                pr.*,
                jsonb_build_object(
                    'available_count', COALESCE(SUM(CASE WHEN tl.stock IS NOT NULL THEN tl.stock ELSE 0 END), 0),
                    'plantskolor_count', COUNT(DISTINCT tl.plantskola_id),
                    'min_price', MIN(tl.price)
                ) as metadata
            FROM plant_results pr
            LEFT JOIN totallager tl ON pr.id = tl.facit_id
            LEFT JOIN plantskolor p ON tl.plantskola_id = p.id
            WHERE 
                tl.hidden = false
                AND p.hidden = false
                AND p.verified = true
                AND (tl.stock > 0 OR tl.stock IS NULL)
            GROUP BY pr.result_type, pr.id, pr.name, pr.secondary_name, pr.plant_type, pr.similarity_score
        )
        SELECT 
            pm.result_type,
            pm.id,
            pm.name,
            pm.secondary_name,
            pm.plant_type,
            pm.similarity_score,
            pm.metadata
        FROM plant_metadata pm
        ORDER BY pm.similarity_score DESC, pm.name ASC
    )
    
    UNION ALL
    
    (
        -- Search plantskolor (nurseries)
        WITH plantskola_results AS (
            SELECT 
                'plantskola'::TEXT as result_type,
                p.id,
                p.name,
                p.postort as secondary_name,
                NULL::TEXT as plant_type,
                -- Calculate relevance score based on match type
                CASE 
                    WHEN sanitize_plant_name(p.name) ILIKE search_term_sanitized || '%' THEN 1.0
                    WHEN sanitize_plant_name(p.name) ILIKE '%' || search_term_sanitized || '%' THEN 0.8
                    WHEN sanitize_plant_name(COALESCE(p.description, '')) ILIKE '%' || search_term_sanitized || '%' THEN 0.6
                    ELSE 0.5
                END::FLOAT as similarity_score,
                p.postorder,
                p.on_site,
                p.phone,
                p.verified
            FROM plantskolor p
            WHERE 
                p.hidden = false
                AND p.verified = true
                AND (
                    sanitize_plant_name(p.name) ILIKE '%' || search_term_sanitized || '%' OR
                    sanitize_plant_name(COALESCE(p.description, '')) ILIKE '%' || search_term_sanitized || '%'
                )
            ORDER BY similarity_score DESC, p.name ASC
            LIMIT result_limit
        )
        SELECT 
            pr.result_type,
            pr.id,
            pr.name,
            pr.secondary_name,
            pr.plant_type,
            pr.similarity_score,
            jsonb_build_object(
                'plant_count', COALESCE(COUNT(DISTINCT tl.facit_id), 0),
                'verified', pr.verified,
                'postorder', pr.postorder,
                'on_site', pr.on_site,
                'phone', pr.phone
            ) as metadata
        FROM plantskola_results pr
        LEFT JOIN totallager tl ON pr.id = tl.plantskola_id
        WHERE tl.hidden = false OR tl.hidden IS NULL
        GROUP BY 
            pr.result_type, pr.id, pr.name, pr.secondary_name, pr.plant_type, 
            pr.similarity_score, pr.verified, pr.postorder, pr.on_site, pr.phone        ORDER BY pr.similarity_score DESC, pr.name ASC
    );    
END;
$$ LANGUAGE plpgsql
SET client_encoding = 'UTF8';

-- =====================================================================================
-- Optimized version for very fast autocomplete (minimal metadata)
-- =====================================================================================

CREATE OR REPLACE FUNCTION search_inline_fast(
    search_term TEXT,
    result_limit INTEGER DEFAULT 5
)
RETURNS TABLE(
    result_type TEXT,
    id BIGINT,
    name TEXT,
    secondary_name TEXT,
    plant_type TEXT,
    similarity_score FLOAT
) AS $$
DECLARE
    search_term_sanitized TEXT;
BEGIN
    -- Sanitize search term for consistent matching
    IF search_term IS NULL OR trim(search_term) = '' THEN
        RETURN;
    END IF;
    
    search_term_sanitized := sanitize_plant_name(search_term);
    
    -- Return empty if sanitized term is too short
    IF length(search_term_sanitized) < 2 THEN
        RETURN;
    END IF;
    
    RETURN QUERY
    (
        -- Fast plant search without aggregations
        SELECT 
            'plant'::TEXT as result_type,
            f.id,
            f.name,
            f.sv_name as secondary_name,
            f.plant_type,
            -- Simple relevance scoring
            CASE 
                WHEN sanitize_plant_name(f.name) ILIKE search_term_sanitized || '%' THEN 1.0
                WHEN sanitize_plant_name(COALESCE(f.sv_name, '')) ILIKE search_term_sanitized || '%' THEN 0.9
                WHEN sanitize_plant_name(f.name) ILIKE '%' || search_term_sanitized || '%' THEN 0.8
                ELSE 0.7
            END::FLOAT as similarity_score
        FROM facit f
        WHERE 
            (
                sanitize_plant_name(f.name) ILIKE '%' || search_term_sanitized || '%' OR
                sanitize_plant_name(COALESCE(f.sv_name, '')) ILIKE '%' || search_term_sanitized || '%'
            )
            -- Simple availability check
            AND EXISTS (
                SELECT 1 FROM totallager tl
                INNER JOIN plantskolor p ON tl.plantskola_id = p.id
                WHERE tl.facit_id = f.id
                AND tl.hidden = false
                AND p.hidden = false
                AND p.verified = true
            )
        ORDER BY 
            CASE 
                WHEN sanitize_plant_name(f.name) ILIKE search_term_sanitized || '%' THEN 1.0
                WHEN sanitize_plant_name(COALESCE(f.sv_name, '')) ILIKE search_term_sanitized || '%' THEN 0.9
                WHEN sanitize_plant_name(f.name) ILIKE '%' || search_term_sanitized || '%' THEN 0.8
                ELSE 0.7
            END DESC,
            f.name ASC
        LIMIT result_limit
    )
    
    UNION ALL
    
    (
        -- Fast plantskola search
        SELECT 
            'plantskola'::TEXT as result_type,
            p.id,
            p.name,
            p.postort as secondary_name,
            NULL::TEXT as plant_type,
            CASE 
                WHEN sanitize_plant_name(p.name) ILIKE search_term_sanitized || '%' THEN 1.0
                WHEN sanitize_plant_name(p.name) ILIKE '%' || search_term_sanitized || '%' THEN 0.8
                ELSE 0.6
            END::FLOAT as similarity_score
        FROM plantskolor p
        WHERE 
            p.hidden = false
            AND p.verified = true
            AND sanitize_plant_name(p.name) ILIKE '%' || search_term_sanitized || '%'
        ORDER BY 
            CASE 
                WHEN sanitize_plant_name(p.name) ILIKE search_term_sanitized || '%' THEN 1.0
                WHEN sanitize_plant_name(p.name) ILIKE '%' || search_term_sanitized || '%' THEN 0.8
                ELSE 0.6
            END DESC,
            p.name ASC        LIMIT result_limit
    );
    
END;
$$ LANGUAGE plpgsql
SET client_encoding = 'UTF8';

-- =====================================================================================
-- Analytics table for inline search tracking
-- =====================================================================================

CREATE TABLE IF NOT EXISTS inline_search_analytics (
    id BIGSERIAL PRIMARY KEY,
    search_term TEXT NOT NULL,
    result_count INTEGER,
    result_types JSONB, -- Count per type: {"plant": 5, "plantskola": 2}
    execution_time_ms NUMERIC,
    user_session TEXT,
    search_timestamp TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_inline_search_analytics_timestamp ON inline_search_analytics (search_timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_inline_search_analytics_term ON inline_search_analytics (search_term);

-- Function to log inline search analytics
CREATE OR REPLACE FUNCTION log_inline_search_analytics(
    p_search_term TEXT,
    p_result_count INTEGER,
    p_result_types JSONB,
    p_execution_time_ms NUMERIC,
    p_user_session TEXT DEFAULT NULL
)
RETURNS void AS $$
BEGIN    INSERT INTO inline_search_analytics (search_term, result_count, result_types, execution_time_ms, user_session)
    VALUES (p_search_term, p_result_count, p_result_types, p_execution_time_ms, p_user_session);
END;
$$ LANGUAGE plpgsql
SET client_encoding = 'UTF8';

-- =====================================================================================
-- Wrapper function with analytics
-- =====================================================================================

CREATE OR REPLACE FUNCTION search_inline_with_analytics(
    search_term TEXT,
    result_limit INTEGER DEFAULT 10,
    user_session TEXT DEFAULT NULL
)
RETURNS TABLE(
    result_type TEXT,
    id BIGINT,
    name TEXT,
    secondary_name TEXT,
    plant_type TEXT,
    similarity_score FLOAT,
    metadata JSONB
) AS $$
DECLARE
    start_time TIMESTAMP;
    end_time TIMESTAMP;
    execution_time_ms NUMERIC;
    result_count INTEGER := 0;
    plant_count INTEGER := 0;
    plantskola_count INTEGER := 0;
    result_types JSONB;
BEGIN
    start_time := clock_timestamp();
    
    -- Execute search and return results
    RETURN QUERY
    SELECT * FROM search_inline(search_term, result_limit);
    
    -- Count results by type for analytics
    SELECT COUNT(*) INTO result_count FROM search_inline(search_term, result_limit);
    SELECT COUNT(*) INTO plant_count FROM search_inline(search_term, result_limit) WHERE result_type = 'plant';
    SELECT COUNT(*) INTO plantskola_count FROM search_inline(search_term, result_limit) WHERE result_type = 'plantskola';
    
    result_types := jsonb_build_object('plant', plant_count, 'plantskola', plantskola_count);
    
    end_time := clock_timestamp();
    execution_time_ms := EXTRACT(EPOCH FROM (end_time - start_time)) * 1000;
    
    -- Log analytics (silently ignore errors)
    BEGIN
        PERFORM log_inline_search_analytics(search_term, result_count, result_types, execution_time_ms, user_session);    EXCEPTION
        WHEN OTHERS THEN
            NULL;
    END;
    
END;
$$ LANGUAGE plpgsql
SET client_encoding = 'UTF8';
