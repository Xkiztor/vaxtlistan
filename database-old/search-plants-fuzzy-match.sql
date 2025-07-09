-- =====================================================================================
-- Function: search_plants_fuzzy_match(search_term, similarity_threshold, result_limit)
-- =====================================================================================
-- 
-- PURPOSE:
-- Fuzzy similarity search for plant names used during import to suggest alternatives
-- when exact matches fail. Displays "menade du?" (did you mean?) options to help
-- users find the correct plant name despite typos or variations.
--
-- PARAMETERS:
-- - search_term: TEXT - The plant name to search for
-- - result_limit: INTEGER - Maximum number of suggestions (default 10)
-- - minimum_similarity: FLOAT - Minimum similarity score (0.0-1.0, default 0.3)
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
-- - similarity_score: FLOAT - Similarity score (0.0-1.0)
-- - match_details: TEXT - JSON string with match information
-- - suggested_reason: TEXT - Why this plant is suggested
--
-- FUZZY MATCHING BEHAVIOR:
-- - Uses PostgreSQL similarity() function or trigram matching
-- - Case and special character insensitive via sanitize_plant_name()
-- - Searches both "name" and "has_synonyms" columns
-- - Excludes synonym plants (synonym_to IS NULL)
-- - Orders results by similarity score (highest first)
-- - Includes similarity threshold filtering
--
-- SIMILARITY ALGORITHMS TO CONSIDER:
-- - pg_trgm extension for trigram similarity
-- - Levenshtein distance for edit distance
-- - Soundex for phonetic matching
-- - Custom weighted scoring combining multiple methods
--
-- PERFORMANCE CONSIDERATIONS:
-- - GIN indexes on trigrams for pg_trgm
-- - Limit results to prevent slow queries
-- - Consider caching common typos/variations
-- - Balance accuracy vs performance
--
-- EXAMPLE USAGE:
-- SELECT * FROM search_plants_fuzzy_match('Pinus cemba', 0.4, 5);
-- SELECT * FROM search_plants_fuzzy_match('Rose Queen Elisabet', 0.3, 10);
--
-- TODO FOR AI IMPLEMENTATION:
-- 1. Enable pg_trgm extension for trigram similarity
-- 2. Use sanitize_plant_name() for search term normalization
-- 3. Apply similarity() function to both name and has_synonyms
-- 4. Filter results by similarity_threshold
-- 5. Exclude plants where synonym_to IS NOT NULL
-- 6. Order by similarity_score DESC
-- 7. Apply result_limit with LIMIT clause
-- 8. Consider creating trigram indexes for performance
-- 9. Handle edge cases (empty search terms, no matches)
-- =====================================================================================

-- =====================================================================================
-- IMPLEMENTATION: search_plants_fuzzy_match_fast (Optimized for client-side similarity)
-- =====================================================================================

-- Fast candidate retrieval function that lets the client handle similarity calculations
CREATE OR REPLACE FUNCTION search_plants_fuzzy_match(
    p_search_term TEXT,
    p_result_limit INTEGER DEFAULT 50,
    p_minimum_similarity FLOAT DEFAULT 0.3 -- Kept for compatibility but not used
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
    match_details TEXT,
    suggested_reason TEXT
) AS $$
DECLARE
    v_sanitized_search_term TEXT;
    v_limit INTEGER;
    v_search_words TEXT[];
    v_first_word TEXT;
    v_search_length INTEGER;
BEGIN
    -- Input validation and defaults
    IF p_search_term IS NULL OR TRIM(p_search_term) = '' THEN
        RETURN;
    END IF;
    
    -- Sanitize and prepare search term
    v_sanitized_search_term := sanitize_plant_name(TRIM(p_search_term));
    IF v_sanitized_search_term IS NULL OR v_sanitized_search_term = '' THEN
        RETURN;
    END IF;
    
    -- Set reasonable limit for fast retrieval
    v_limit := GREATEST(10, LEAST(100, COALESCE(p_result_limit, 50)));
    
    -- Extract search components for efficient filtering
    v_search_words := string_to_array(v_sanitized_search_term, ' ');
    v_first_word := CASE WHEN array_length(v_search_words, 1) > 0 THEN v_search_words[1] ELSE v_sanitized_search_term END;
    v_search_length := LENGTH(v_sanitized_search_term);
      -- Fast candidate retrieval using simple but efficient database operations
    RETURN QUERY
    WITH fast_candidates AS (
        -- Simplified primary matches using fewer sanitize_plant_name calls
        SELECT DISTINCT
            f.id,
            f.name,
            f.sv_name,
            f.plant_type,
            f.has_synonyms,
            f.has_synonyms_id,
            f.user_submitted,
            f.created_by,
            -- Simplified scoring for database sorting (client will recalculate)
            CASE 
                WHEN f.name ILIKE v_sanitized_search_term THEN 1.0
                WHEN f.name ILIKE v_sanitized_search_term || '%' THEN 0.9
                WHEN f.name ILIKE '%' || v_sanitized_search_term || '%' THEN 0.8
                WHEN f.sv_name ILIKE v_sanitized_search_term || '%' THEN 0.85
                WHEN f.sv_name ILIKE '%' || v_sanitized_search_term || '%' THEN 0.75
                WHEN f.has_synonyms ILIKE '%' || v_sanitized_search_term || '%' THEN 0.7
                ELSE 0.6
            END AS db_score
        FROM facit f
        WHERE f.synonym_to IS NULL
        AND (
            -- Simplified text matching conditions (assuming data is already sanitized)
            f.name ILIKE '%' || v_sanitized_search_term || '%'
            OR f.sv_name ILIKE '%' || v_sanitized_search_term || '%'
            OR f.has_synonyms ILIKE '%' || v_sanitized_search_term || '%'
            -- Word-based matching for multi-word searches
            OR (
                array_length(v_search_words, 1) > 1 
                AND f.name ILIKE '%' || v_first_word || '%'
            )
            -- Length-based candidates for very short searches
            OR (
                v_search_length <= 4 
                AND f.name ILIKE v_sanitized_search_term || '%'
            )
        )
        LIMIT v_limit * 2 -- Get more candidates but limit early for performance
    )
    SELECT 
        fc.id,
        fc.name,
        fc.sv_name,
        fc.plant_type,
        fc.has_synonyms,
        fc.has_synonyms_id,
        fc.user_submitted,
        fc.created_by,
        -- Return placeholder similarity score - client will recalculate
        0.0::FLOAT as similarity_score,
        -- Return basic match info for client processing
        json_build_object(
            'search_term', v_sanitized_search_term,
            'search_length', v_search_length,
            'result_length', LENGTH(fc.name),
            'db_score', fc.db_score
        )::TEXT as match_details,
        -- Placeholder reason - client will determine
        'Klient beräknar' as suggested_reason
    FROM fast_candidates fc
    ORDER BY 
        fc.db_score DESC,
        LENGTH(fc.name) ASC,
        fc.name ASC
    LIMIT v_limit;
    
END;
$$ LANGUAGE plpgsql
SET client_encoding = 'UTF8';

-- =====================================================================================
-- Lightweight candidate retrieval function for client-side fuzzy matching
-- =====================================================================================
-- Note: Manual similarity calculation functions removed for performance.
-- All fuzzy matching is now handled on the client side using useFuzzyMatch composable.

-- =====================================================================================
-- Optimized batch version for import processing (client-side similarity)
-- =====================================================================================

CREATE OR REPLACE FUNCTION search_plants_fuzzy_match_batch(
    p_search_terms TEXT[],
    p_result_limit INTEGER DEFAULT 25,
    p_minimum_similarity FLOAT DEFAULT 0.3
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
    match_details TEXT,
    suggested_reason TEXT
) AS $$
DECLARE
    v_limit INTEGER;
    search_term TEXT;
BEGIN
    -- Input validation
    IF p_search_terms IS NULL OR array_length(p_search_terms, 1) = 0 THEN
        RETURN;
    END IF;
    
    v_limit := GREATEST(5, LEAST(50, COALESCE(p_result_limit, 25)));
    
    -- Process each search term using the optimized single-term function
    FOREACH search_term IN ARRAY p_search_terms
    LOOP
        IF search_term IS NOT NULL AND TRIM(search_term) != '' THEN
            RETURN QUERY
            SELECT 
                search_term,
                candidates.id,
                candidates.name,
                candidates.sv_name,
                candidates.plant_type,
                candidates.has_synonyms,
                candidates.has_synonyms_id,
                candidates.user_submitted,
                candidates.created_by,
                candidates.similarity_score,
                candidates.match_details,
                candidates.suggested_reason
            FROM search_plants_fuzzy_match(search_term, v_limit, p_minimum_similarity) AS candidates;
        END IF;
    END LOOP;
    
END;
$$ LANGUAGE plpgsql
SET client_encoding = 'UTF8';

-- =====================================================================================
-- Performance optimization indexes for fast candidate retrieval
-- =====================================================================================

-- Drop old trigram indexes if they exist (no longer needed for client-side similarity)
DROP INDEX IF EXISTS idx_facit_name_trigram_gin;
DROP INDEX IF EXISTS idx_facit_sv_name_trigram_gin;
DROP INDEX IF EXISTS idx_facit_synonyms_trigram_gin;

-- Optimized indexes for fast text search and filtering
-- These support ILIKE operations and prefix matching efficiently

-- Primary index for main plant names with text pattern operations
CREATE INDEX IF NOT EXISTS idx_facit_name_text_ops 
ON facit USING btree (sanitize_plant_name(name) text_pattern_ops)
WHERE synonym_to IS NULL;

-- Index for Swedish names text search
CREATE INDEX IF NOT EXISTS idx_facit_sv_name_text_ops 
ON facit USING btree (sanitize_plant_name(sv_name) text_pattern_ops)
WHERE synonym_to IS NULL AND sv_name IS NOT NULL AND sv_name != '';

-- Composite index for efficient candidate filtering
CREATE INDEX IF NOT EXISTS idx_facit_candidate_retrieval
ON facit (id, name, sv_name, plant_type, has_synonyms, user_submitted, created_by)
WHERE synonym_to IS NULL;

-- Index for synonym search (kept simple since client handles matching)
CREATE INDEX IF NOT EXISTS idx_facit_synonyms_simple
ON facit (has_synonyms)
WHERE synonym_to IS NULL 
AND has_synonyms IS NOT NULL 
AND has_synonyms != '';

-- Index for length-based prefix matching on short searches
CREATE INDEX IF NOT EXISTS idx_facit_name_prefix
ON facit (LEFT(sanitize_plant_name(name), 4))
WHERE synonym_to IS NULL;

-- Index for Swedish exact matches
CREATE INDEX IF NOT EXISTS idx_facit_sv_exact_match
ON facit (sanitize_plant_name(sv_name))
WHERE synonym_to IS NULL AND sv_name IS NOT NULL AND sv_name != '';

-- Statistics update for better query planning
ANALYZE facit;
