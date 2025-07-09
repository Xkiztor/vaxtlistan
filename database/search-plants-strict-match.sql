-- =====================================================================================
-- Function: search_plants_strict_match(search_term, minimum_similarity)
-- =====================================================================================
-- 
-- PURPOSE:
-- Strict name matching function used during plant import process.
-- Performs exact case and special character insensitive matching for reliable
-- plant identification during CSV imports and data validation.
--
-- PARAMETERS:
-- - search_term: TEXT - The exact plant name to match
-- - minimum_similarity: FLOAT - Minimum similarity threshold (default 0.8)
--
-- RETURNS:
-- Table with columns:
-- - id: BIGINT - Plant ID from facit table
-- - name: TEXT - Scientific plant name
-- - sv_name: TEXT - Swedish/common name  
-- - plant_type: TEXT - Type classification
-- - has_synonyms: TEXT - Pipe-separated list of synonym names
-- - has_synonyms_id: TEXT - Pipe-separated list of synonym IDs
-- - user_submitted: BOOLEAN - Whether plant was user-submitted
-- - created_by: BIGINT - ID of user/nursery who created entry
-- - similarity_score: FLOAT - Similarity score (1.0 for exact matches)
-- - is_exact_match: BOOLEAN - Whether this is an exact match
-- - match_type: TEXT - Type of match ('name', 'sv_name', or 'synonym')
--
-- MATCHING BEHAVIOR:
-- - Exact match after sanitization (no partial matching)
-- - Case and special character insensitive using sanitize_plant_name()
-- - Searches in both "name" and "has_synonyms" columns
-- - Excludes synonym plants (synonym_to IS NULL)
-- - Returns all exact matches (multiple cultivars of same species)
--
-- USE CASES:
-- - Import validation: verify plant names exist in database
-- - Data quality checks: ensure consistent naming
-- - Duplicate detection during plant entry
-- - API endpoints requiring exact plant identification
--
-- PERFORMANCE CONSIDERATIONS:
-- - Should be very fast since it's exact matching
-- - Index on sanitized names for optimal performance
-- - No LIMIT needed since exact matches should be few
--
-- EXAMPLE USAGE:
-- SELECT * FROM search_plants_strict_match('Pinus cembra Stricta', 0.8);
-- SELECT * FROM search_plants_strict_match('Rosa Queen Elizabeth', 0.9);
--
-- TODO FOR AI IMPLEMENTATION:
-- 1. Use sanitize_plant_name() for both search term and database values
-- 2. Perform exact equality comparison (=) not LIKE
-- 3. Check both sanitized name and sanitized has_synonyms
-- 4. Exclude plants where synonym_to IS NOT NULL
-- 5. Return all matching records (no artificial limits)
-- 6. Consider using UNION for name and synonym searches
-- 7. Add proper indexing recommendations
-- =====================================================================================

-- =====================================================================================
-- IMPLEMENTATION: search_plants_strict_match
-- =====================================================================================

CREATE OR REPLACE FUNCTION search_plants_strict_match(
    p_search_term TEXT,
    p_minimum_similarity FLOAT DEFAULT 0.8
)
RETURNS TABLE(
    id BIGINT,
    name TEXT,
    sv_name TEXT,
    plant_type TEXT,
    has_synonyms TEXT,
    has_synonyms_id TEXT,
    user_submitted BOOLEAN,
    created_by BIGINT,
    similarity_score FLOAT,
    is_exact_match BOOLEAN,
    match_type TEXT
) AS $$
DECLARE
    v_sanitized_search_term TEXT;
BEGIN
    -- Input validation
    IF p_search_term IS NULL OR TRIM(p_search_term) = '' THEN
        RETURN; -- Return empty result set for invalid input
    END IF;
    
    -- Sanitize the search term for consistent matching
    v_sanitized_search_term := sanitize_plant_name(TRIM(p_search_term));
    
    -- If sanitization failed or resulted in empty string, return no results
    IF v_sanitized_search_term IS NULL OR v_sanitized_search_term = '' THEN
        RETURN;
    END IF;    -- Perform exact match search using UNION to search both name and synonyms
    -- This approach ensures we find all exact matches efficiently
    RETURN QUERY
    WITH all_matches AS (
        -- Search in main plant names (excluding synonyms)
        SELECT 
            f.id,
            f.name,
            f.sv_name,
            f.plant_type,
            f.has_synonyms,
            f.has_synonyms_id,
            f.user_submitted,
            f.created_by,
            1.0::FLOAT as similarity_score, -- Exact match
            true as is_exact_match,
            'name'::TEXT as match_type
        FROM facit f
        WHERE f.synonym_to IS NULL  -- Exclude synonym plants
        AND sanitize_plant_name(f.name) = v_sanitized_search_term
        
        UNION
        
        -- Search in Swedish names
        SELECT 
            f.id,
            f.name,
            f.sv_name,
            f.plant_type,
            f.has_synonyms,
            f.has_synonyms_id,
            f.user_submitted,
            f.created_by,
            1.0::FLOAT as similarity_score, -- Exact match
            true as is_exact_match,
            'sv_name'::TEXT as match_type
        FROM facit f
        WHERE f.synonym_to IS NULL  -- Exclude synonym plants
        AND f.sv_name IS NOT NULL
        AND f.sv_name != ''
        AND sanitize_plant_name(f.sv_name) = v_sanitized_search_term
        
        UNION
        
        -- Search in synonym names (but return the main plant, not the synonym)
        SELECT 
            f.id,
            f.name,
            f.sv_name,
            f.plant_type,
            f.has_synonyms,
            f.has_synonyms_id,
            f.user_submitted,
            f.created_by,
            1.0::FLOAT as similarity_score, -- Exact match via synonym
            true as is_exact_match,
            'synonym'::TEXT as match_type
        FROM facit f
        WHERE f.synonym_to IS NULL  -- Only main plants (not synonyms themselves)
        AND f.has_synonyms IS NOT NULL
        AND f.has_synonyms != ''
        AND EXISTS (
            -- Check if any of the pipe-separated synonyms matches exactly
            SELECT 1 
            FROM unnest(string_to_array(f.has_synonyms, '|')) AS synonym_name
            WHERE sanitize_plant_name(TRIM(synonym_name)) = v_sanitized_search_term
        )
    )
    SELECT 
        am.id,
        am.name,
        am.sv_name,
        am.plant_type,
        am.has_synonyms,
        am.has_synonyms_id,
        am.user_submitted,
        am.created_by,
        am.similarity_score,
        am.is_exact_match,
        am.match_type
    FROM all_matches am
    ORDER BY 
        -- Prioritize exact name matches over synonym matches
        CASE 
            WHEN am.match_type = 'name' THEN 1
            WHEN am.match_type = 'sv_name' THEN 2
            ELSE 3
        END,
        -- Then order by name for consistency
        am.name ASC;
    
END;
$$ LANGUAGE plpgsql
SET client_encoding = 'UTF8';

-- =====================================================================================
-- Batch version for improved performance during imports
-- =====================================================================================

CREATE OR REPLACE FUNCTION search_plants_strict_match_batch(
    p_search_terms TEXT[],
    p_minimum_similarity FLOAT DEFAULT 0.8
)
RETURNS TABLE(
    search_term TEXT,
    id BIGINT,
    name TEXT,
    sv_name TEXT,
    plant_type TEXT,
    has_synonyms TEXT,
    has_synonyms_id TEXT,
    user_submitted BOOLEAN,
    created_by BIGINT,
    similarity_score FLOAT,
    is_exact_match BOOLEAN,
    match_type TEXT
) AS $$
DECLARE
    v_sanitized_terms TEXT[];
    v_term TEXT;
BEGIN
    -- Input validation
    IF p_search_terms IS NULL OR array_length(p_search_terms, 1) = 0 THEN
        RETURN; -- Return empty result set for invalid input
    END IF;
    
    -- Sanitize all search terms
    v_sanitized_terms := ARRAY[]::TEXT[];
    FOREACH v_term IN ARRAY p_search_terms
    LOOP
        IF v_term IS NOT NULL AND TRIM(v_term) != '' THEN
            v_sanitized_terms := array_append(v_sanitized_terms, sanitize_plant_name(TRIM(v_term)));
        END IF;
    END LOOP;
    
    -- If no valid terms after sanitization, return empty
    IF array_length(v_sanitized_terms, 1) = 0 THEN
        RETURN;
    END IF;    -- Perform batch exact match search
    RETURN QUERY
    WITH search_data AS (
        SELECT 
            unnest(p_search_terms) AS original_term,
            unnest(v_sanitized_terms) AS sanitized_term
    ),
    name_matches AS (
        -- Search in main plant names
        SELECT 
            sd.original_term,
            f.id,
            f.name,
            f.sv_name,
            f.plant_type,
            f.has_synonyms,
            f.has_synonyms_id,
            f.user_submitted,
            f.created_by,
            1.0::FLOAT as similarity_score,
            true as is_exact_match,
            'name'::TEXT as match_type,
            1 as match_priority -- Name matches have higher priority
        FROM search_data sd
        INNER JOIN facit f ON sanitize_plant_name(f.name) = sd.sanitized_term
        WHERE f.synonym_to IS NULL
    ),
    synonym_matches AS (
        -- Search in synonym names
        SELECT 
            sd.original_term,
            f.id,
            f.name,
            f.sv_name,
            f.plant_type,
            f.has_synonyms,
            f.has_synonyms_id,
            f.user_submitted,
            f.created_by,
            1.0::FLOAT as similarity_score,
            true as is_exact_match,
            'synonym'::TEXT as match_type,
            2 as match_priority -- Synonym matches have lower priority
        FROM search_data sd
        INNER JOIN facit f ON f.synonym_to IS NULL
        WHERE f.has_synonyms IS NOT NULL
        AND f.has_synonyms != ''
        AND EXISTS (
            SELECT 1 
            FROM unnest(string_to_array(f.has_synonyms, '|')) AS synonym_name
            WHERE sanitize_plant_name(TRIM(synonym_name)) = sd.sanitized_term
        )
    ),
    all_results AS (
        SELECT 
            nm.original_term,
            nm.id,
            nm.name,
            nm.sv_name,
            nm.plant_type,
            nm.has_synonyms,
            nm.has_synonyms_id,
            nm.user_submitted,
            nm.created_by,
            nm.similarity_score,
            nm.is_exact_match,
            nm.match_type,
            nm.match_priority
        FROM name_matches nm
        
        UNION ALL
        
        SELECT 
            sm.original_term,
            sm.id,
            sm.name,
            sm.sv_name,
            sm.plant_type,
            sm.has_synonyms,
            sm.has_synonyms_id,
            sm.user_submitted,
            sm.created_by,
            sm.similarity_score,
            sm.is_exact_match,
            sm.match_type,
            sm.match_priority
        FROM synonym_matches sm
        -- Only include synonym matches if no name match exists for this term
        WHERE NOT EXISTS (
            SELECT 1 FROM name_matches nm 
            WHERE nm.original_term = sm.original_term
        )
    )
    SELECT 
        ar.original_term,
        ar.id,
        ar.name,
        ar.sv_name,
        ar.plant_type,
        ar.has_synonyms,
        ar.has_synonyms_id,
        ar.user_submitted,
        ar.created_by,
        ar.similarity_score,
        ar.is_exact_match,
        ar.match_type
    FROM all_results ar
    ORDER BY ar.original_term, ar.match_priority, ar.name;
    
END;
$$ LANGUAGE plpgsql
SET client_encoding = 'UTF8';

-- =====================================================================================
-- Performance optimization indexes
-- =====================================================================================

-- Index for fast exact matching on sanitized names
CREATE INDEX IF NOT EXISTS idx_facit_sanitized_name_exact 
ON facit (sanitize_plant_name(name)) 
WHERE synonym_to IS NULL;

-- Index for synonym search optimization
CREATE INDEX IF NOT EXISTS idx_facit_has_synonyms_not_null 
ON facit (id) 
WHERE synonym_to IS NULL 
AND has_synonyms IS NOT NULL 
AND has_synonyms != '';

-- Partial index for non-synonym plants only (improves exact match performance)
CREATE INDEX IF NOT EXISTS idx_facit_main_plants_only 
ON facit (id, name, plant_type) 
WHERE synonym_to IS NULL;
