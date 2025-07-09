-- =====================================================================================
-- FUZZY PLANT SEARCH FUNCTION (For typos and variations)
-- =====================================================================================
-- 
-- PURPOSE:
-- Provides fuzzy similarity search for plant names to allow for typos and variations.
-- Used when exact matching fails to find results.
--
-- FEATURES:
-- - Uses pg_trgm (trigram) extension for fuzzy matching with GIN indexes
-- - Centralized sanitization via sanitize_plant_name() function
-- - Excludes synonym plants (where synonym_to has content)
-- - Searches both main name and synonym fields
-- - Optimized for performance on 170k+ plant records
-- - Returns similarity score for ranking results
--
-- USAGE:
-- SELECT * FROM plants_match_fuzzy('pinus cemba', 10, 0.3);  -- Limited results
-- SELECT * FROM plants_match_fuzzy('pinus cemba', 0, 0.3);   -- All matching results
-- =====================================================================================

-- Ensure pg_trgm extension is available (required for trigram matching)
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS plants_match_fuzzy(TEXT);

-- Create the fuzzy search function
CREATE OR REPLACE FUNCTION plants_match_fuzzy(
    p_search_term TEXT
)
RETURNS TABLE(
    id BIGINT,
    name TEXT,
    sv_name TEXT,
    plant_type TEXT,
    grupp TEXT,
    serie TEXT,
    has_synonyms TEXT,
    has_synonyms_id TEXT,
    user_submitted BOOLEAN,
    created_by BIGINT,
    match_details TEXT,
    matched_synonym_name TEXT,
    matched_synonym_id TEXT
)
AS $$
DECLARE
    sanitized_search_term TEXT;
BEGIN
    -- Validate and sanitize input parameters
    IF p_search_term IS NULL OR LENGTH(TRIM(p_search_term)) = 0 THEN
        RETURN;
    END IF;

    
    -- Sanitize the search term using centralized function
    sanitized_search_term := sanitize_plant_name(p_search_term);
      -- If sanitization results in empty string, return no results
    IF sanitized_search_term IS NULL OR LENGTH(sanitized_search_term) = 0 THEN
        RETURN;
    END IF;
      -- Execute fuzzy search with trigram matching
    RETURN QUERY
    SELECT 
        f.id,
        f.name,
        f.sv_name,
        f.plant_type,
        f.grupp,
        f.serie,
        f.has_synonyms,
        f.has_synonyms_id,
        f.user_submitted,
        f.created_by,
        -- Determine match details for client-side strategy detection
        CASE 
            WHEN sanitize_plant_name(f.name) % sanitized_search_term THEN 'fast_match'
            WHEN f.has_synonyms IS NOT NULL 
                 AND LENGTH(f.has_synonyms) > 0 
                 AND EXISTS(
                     SELECT 1 FROM unnest(string_to_array(f.has_synonyms, ' | ')) AS synonym
                     WHERE LENGTH(TRIM(synonym)) > 0 
                     AND sanitize_plant_name(TRIM(synonym)) % sanitized_search_term
                 ) THEN 'synonym_match'
            WHEN LENGTH(sanitized_search_term) > 10 THEN 'multi_word_match'
            ELSE 'fallback_match'
        END AS match_details,
        -- Calculate which synonym was matched (if any)
        CASE 
            WHEN f.has_synonyms IS NOT NULL AND LENGTH(f.has_synonyms) > 0 THEN
                (SELECT TRIM(synonym)
                 FROM unnest(string_to_array(f.has_synonyms, ' | ')) AS synonym
                 WHERE LENGTH(TRIM(synonym)) > 0
                 AND sanitize_plant_name(TRIM(synonym)) % sanitized_search_term
                 LIMIT 1)
            ELSE NULL
        END AS matched_synonym_name,
        -- Calculate the ID of the matched synonym
        CASE 
            WHEN f.has_synonyms IS NOT NULL AND LENGTH(f.has_synonyms) > 0 AND f.has_synonyms_id IS NOT NULL THEN
                (SELECT TRIM(COALESCE(split_part(f.has_synonyms_id, ' | ', syn_pos::integer), ''))
                 FROM unnest(string_to_array(f.has_synonyms, ' | ')) WITH ORDINALITY AS t(synonym, syn_pos)
                 WHERE LENGTH(TRIM(synonym)) > 0
                 AND sanitize_plant_name(TRIM(synonym)) % sanitized_search_term
                 LIMIT 1)
            ELSE NULL
        END AS matched_synonym_id
    FROM facit f
    WHERE 
        -- Exclude synonym plants (only include accepted names)
        (f.synonym_to IS NULL OR LENGTH(TRIM(f.synonym_to)) = 0)
        AND (
            -- Pre-filter using trigram % operator
            sanitize_plant_name(f.name) % sanitized_search_term
            OR
            -- Also check individual synonyms for trigram matches
            (f.has_synonyms IS NOT NULL 
             AND LENGTH(f.has_synonyms) > 0 
             AND EXISTS(
                 SELECT 1 FROM unnest(string_to_array(f.has_synonyms, ' | ')) AS synonym
                 WHERE LENGTH(TRIM(synonym)) > 0 
                 AND sanitize_plant_name(TRIM(synonym)) % sanitized_search_term
             ))
        )
    ORDER BY 
        LENGTH(f.name) ASC,            -- Shorter names first
        f.name ASC;                     -- Alphabetical as tiebreaker    
        

EXCEPTION
    WHEN OTHERS THEN
        -- Log error and return empty result set
        RAISE WARNING 'Error in plants_match_fuzzy: %', SQLERRM;
        RETURN;
END;
$$ LANGUAGE plpgsql STABLE
SET search_path = public;

-- =====================================================================================
-- Performance Optimization: Required Indexes
-- =====================================================================================
-- 
-- These indexes are CRITICAL for performance with 170k+ rows.
-- Create them after deploying the function for optimal search speed.
-- =====================================================================================

-- -- Trigram indexes for fuzzy search performance
-- CREATE INDEX IF NOT EXISTS idx_facit_name_trigram_gin 
-- ON facit USING gin (sanitize_plant_name(name) gin_trgm_ops)
-- WHERE synonym_to IS NULL OR LENGTH(TRIM(synonym_to)) = 0;

-- CREATE INDEX IF NOT EXISTS idx_facit_synonyms_trigram_gin 
-- ON facit USING gin (sanitize_plant_name(has_synonyms) gin_trgm_ops)
-- WHERE (synonym_to IS NULL OR LENGTH(TRIM(synonym_to)) = 0)
--   AND has_synonyms IS NOT NULL 
--   AND LENGTH(has_synonyms) > 0;

-- -- Composite index for filtering synonym plants
-- CREATE INDEX IF NOT EXISTS idx_facit_synonym_to_filter
-- ON facit (synonym_to)
-- WHERE synonym_to IS NULL OR LENGTH(TRIM(synonym_to)) = 0;

-- =====================================================================================
-- Usage Examples
-- =====================================================================================
-- 
-- MAIN FUNCTION (Use this from web app):
-- SELECT * FROM plants_match('Pinus cembra');               -- All matches 
-- SELECT * FROM plants_match('pinus cemba', 20, 0.3);       -- Limited matches
-- 
-- SPECIALIZED FUNCTIONS (for direct access if needed):
-- SELECT * FROM plants_match_strict('Pinus cembra');        -- All exact matches
-- SELECT * FROM plants_match_fuzzy('pinus cemba', 0, 0.25); -- All fuzzy matches
-- 
-- MATCH DETAILS INTERPRETATION:
-- - 'exact_match' = Perfect exact match on main name
-- - 'synonym_exact_match' = Perfect exact match on synonym
-- - 'fast_match' = High confidence trigram match on main name
-- - 'synonym_match' = Good trigram match on synonym
-- - 'multi_word_match' = Long search term match
-- - 'fallback_match' = Low confidence match
-- =====================================================================================
-- STRICT PLANT SEARCH FUNCTION (Exact matching only)
-- =====================================================================================
-- 
-- PURPOSE:
-- Provides ultra-fast exact matching for plant names using B-tree indexes.
-- Only returns exact matches - no fallbacks or fuzzy logic.
--
-- STRATEGY:
-- 1. Exact match on sanitized plant name (fastest)
-- 2. Exact match on individual synonyms (very fast)
--
-- PERFORMANCE:
-- - Uses B-tree indexes for O(log n) lookup time
-- - Sanitized exact matches are nearly instantaneous
-- - No trigram calculations needed
--
-- USAGE:
-- SELECT * FROM plants_match_strict('Pinus cembra');      -- All exact matches
-- SELECT * FROM plants_match_strict('Pinus cembra', 10);  -- Limited exact matches
-- =====================================================================================

-- Drop existing strict search function if it exists
DROP FUNCTION IF EXISTS plants_match_strict(TEXT);

-- Create the strict search function
CREATE OR REPLACE FUNCTION plants_match_strict(
    p_search_term TEXT
)
RETURNS TABLE(
    id BIGINT,
    name TEXT,
    sv_name TEXT,
    plant_type TEXT,
    grupp TEXT,
    serie TEXT,
    has_synonyms TEXT,
    has_synonyms_id TEXT,
    user_submitted BOOLEAN,
    created_by BIGINT,
    match_details TEXT,
    matched_synonym_name TEXT,
    matched_synonym_id TEXT
)
AS $$
DECLARE
    sanitized_search_term TEXT;
BEGIN
    -- Validate input parameters
    IF p_search_term IS NULL OR LENGTH(TRIM(p_search_term)) = 0 THEN
        RETURN;
    END IF;

    
    -- Sanitize the search term using centralized function
    sanitized_search_term := sanitize_plant_name(p_search_term);
    
    -- If sanitization results in empty string, return no results
    IF sanitized_search_term IS NULL OR LENGTH(sanitized_search_term) = 0 THEN
        RETURN;
    END IF;    -- =====================================================================================
    -- Exact match on sanitized plant name (uses B-tree index)
    -- =====================================================================================
    RETURN QUERY
    SELECT 
        f.id,
        f.name,
        f.sv_name,
        f.plant_type,
        f.grupp,
        f.serie,
        f.has_synonyms,
        f.has_synonyms_id,
        f.user_submitted,
        f.created_by,
        'exact_match'::TEXT AS match_details,
        NULL::TEXT AS matched_synonym_name,
        NULL::TEXT AS matched_synonym_id
    FROM facit f
    WHERE 
        -- Exclude synonym plants (only include accepted names)
        (f.synonym_to IS NULL OR LENGTH(TRIM(f.synonym_to)) = 0)
        -- Exact match on sanitized name        
        AND sanitize_plant_name(f.name) = sanitized_search_term
    ORDER BY 
        LENGTH(f.name) ASC,  -- Shorter names first
        f.name ASC;           -- Alphabetical

    -- =====================================================================================
    -- Exact match on individual synonyms
    -- =====================================================================================
    RETURN QUERY
    SELECT 
        f.id,
        f.name,
        f.sv_name,
        f.plant_type,
        f.grupp,
        f.serie,
        f.has_synonyms,
        f.has_synonyms_id,
        f.user_submitted,
        f.created_by,
        'synonym_exact_match'::TEXT AS match_details,
        -- Find the exact matching synonym
        (SELECT TRIM(synonym)
         FROM unnest(string_to_array(f.has_synonyms, ' | ')) AS synonym
         WHERE sanitize_plant_name(TRIM(synonym)) = sanitized_search_term
         AND LENGTH(TRIM(synonym)) > 0
         LIMIT 1) AS matched_synonym_name,
        -- Find the corresponding synonym ID
        (SELECT TRIM(COALESCE(split_part(f.has_synonyms_id, ' | ', syn_pos::integer), ''))
         FROM unnest(string_to_array(f.has_synonyms, ' | ')) WITH ORDINALITY AS t(synonym, syn_pos)
         WHERE sanitize_plant_name(TRIM(synonym)) = sanitized_search_term
         AND LENGTH(TRIM(synonym)) > 0
         LIMIT 1) AS matched_synonym_id
    FROM facit f
    WHERE 
        -- Exclude synonym plants
        (f.synonym_to IS NULL OR LENGTH(TRIM(f.synonym_to)) = 0)
        -- Has synonyms to check
        AND f.has_synonyms IS NOT NULL 
        AND LENGTH(f.has_synonyms) > 0
        -- Check if any individual synonym matches exactly
        AND EXISTS(
            SELECT 1 
            FROM unnest(string_to_array(f.has_synonyms, ' | ')) AS synonym
            WHERE sanitize_plant_name(TRIM(synonym)) = sanitized_search_term
            AND LENGTH(TRIM(synonym)) > 0
        )
        -- Exclude plants already found in the exact name match
        AND f.id NOT IN (
            SELECT sub_f.id
            FROM facit sub_f
            WHERE (sub_f.synonym_to IS NULL OR LENGTH(TRIM(sub_f.synonym_to)) = 0)            
            AND sanitize_plant_name(sub_f.name) = sanitized_search_term
        )
    ORDER BY 
        LENGTH(f.name) ASC,  -- Shorter names first
        f.name ASC;           -- Alphabetical

EXCEPTION
    WHEN OTHERS THEN
        -- Log error and return empty result set
        RAISE WARNING 'Error in plants_match_strict: %', SQLERRM;
        RETURN;
END;
$$ LANGUAGE plpgsql STABLE
SET search_path = public;

-- =====================================================================================
-- MAIN PLANT SEARCH FUNCTION (Single entry point for web app)
-- =====================================================================================
-- 
-- PURPOSE:
-- Single function that handles the complete plant search strategy.
-- This is the ONLY function that should be called from the web application.
--
-- STRATEGY:
-- 1. First: Try ultra-fast strict matching (exact matches only)
-- 2. If no strict matches: Try fuzzy search with intelligent promotion
-- 3. Auto-promote fuzzy matches with 0.9+ similarity to "direct_fuzzy_match"
--
-- PERFORMANCE:
-- - Exact matches: Nearly instantaneous with B-tree indexes
-- - Fuzzy fallback: Only when needed, with smart confidence detection
-- - Returns immediately when high-confidence matches are found
--
-- USAGE:
-- SELECT * FROM plants_match('Pinus cembra');        -- All matches (exact + fuzzy)
-- SELECT * FROM plants_match('pinus cemba', 20, 0.3); -- Limited matches with custom params
-- =====================================================================================

-- Drop existing main search function if it exists
DROP FUNCTION IF EXISTS plants_match(TEXT);

-- Create the main search function
CREATE OR REPLACE FUNCTION plants_match(
    p_search_term TEXT
)
RETURNS TABLE(
    id BIGINT,
    name TEXT,
    sv_name TEXT,
    plant_type TEXT,
    grupp TEXT,
    serie TEXT,
    has_synonyms TEXT,
    has_synonyms_id TEXT,
    user_submitted BOOLEAN,
    created_by BIGINT,
    match_details TEXT,
    matched_synonym_name TEXT,
    matched_synonym_id TEXT
)
AS $$
DECLARE
    strict_result_count INTEGER := 0;
    v_limit INTEGER;
BEGIN
    -- Validate input parameters
    IF p_search_term IS NULL OR LENGTH(TRIM(p_search_term)) = 0 THEN
        RETURN;
    END IF;    -- =====================================================================================
    -- PHASE 1: Try ultra-fast strict matching first
    -- =====================================================================================
    RETURN QUERY
    SELECT 
        strict_results.id,
        strict_results.name,
        strict_results.sv_name,
        strict_results.plant_type,
        strict_results.grupp,
        strict_results.serie,
        strict_results.has_synonyms,
        strict_results.has_synonyms_id,
        strict_results.user_submitted,
        strict_results.created_by,
        strict_results.match_details,
        strict_results.matched_synonym_name,
        strict_results.matched_synonym_id
    FROM plants_match_strict(p_search_term) AS strict_results;
    
    -- Check if strict search found results
    GET DIAGNOSTICS strict_result_count = ROW_COUNT;
    
    -- =====================================================================================
    -- PHASE 2: If no strict matches, try fuzzy search
    -- =====================================================================================
    IF strict_result_count = 0 THEN
        RETURN QUERY
        SELECT 
            fuzzy_results.id,
            fuzzy_results.name,
            fuzzy_results.sv_name,
            fuzzy_results.plant_type,
            fuzzy_results.grupp,
            fuzzy_results.serie,
            fuzzy_results.has_synonyms,
            fuzzy_results.has_synonyms_id,
            fuzzy_results.user_submitted,
            fuzzy_results.created_by,
            fuzzy_results.match_details,
            fuzzy_results.matched_synonym_name,
            fuzzy_results.matched_synonym_id
        FROM plants_match_fuzzy(p_search_term) AS fuzzy_results
        ORDER BY 
            LENGTH(fuzzy_results.name) ASC,
            fuzzy_results.name ASC;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        -- Log error and return empty result set
        RAISE WARNING 'Error in plants_match: %', SQLERRM;
        RETURN;
END;
$$ LANGUAGE plpgsql STABLE
SET search_path = public;

-- =====================================================================================
-- Performance Optimization: Additional Indexes for Strict Matching
-- =====================================================================================
-- 
-- These indexes are CRITICAL for ultra-fast strict matching performance.
-- B-tree indexes provide O(log n) lookup time for exact matches.
-- =====================================================================================

-- -- B-tree index for sanitized plant names (strict matching)
-- CREATE INDEX IF NOT EXISTS idx_facit_name_sanitized_btree 
-- ON facit (sanitize_plant_name(name))
-- WHERE synonym_to IS NULL OR LENGTH(TRIM(synonym_to)) = 0;

-- -- B-tree index for case-insensitive fallback
-- CREATE INDEX IF NOT EXISTS idx_facit_name_sanitized_lower_btree 
-- ON facit (LOWER(sanitize_plant_name(name)))
-- WHERE synonym_to IS NULL OR LENGTH(TRIM(synonym_to)) = 0;

-- -- Composite index for synonym filtering (strict matching)
-- CREATE INDEX IF NOT EXISTS idx_facit_has_synonyms_filter
-- ON facit (id)
-- WHERE (synonym_to IS NULL OR LENGTH(TRIM(synonym_to)) = 0)
--   AND has_synonyms IS NOT NULL 
--   AND LENGTH(has_synonyms) > 0;