-- =====================================================================================
-- Function: search_all_plants(search_term, result_limit)
-- =====================================================================================
-- 
-- PURPOSE:
-- Advanced search function for all plants used in PlantPicker component.
-- Uses sophisticated trigram similarity matching with synonym splitting for optimal
-- user experience. Searches the full 170k plant database with fuzzy matching capabilities.
--
-- PARAMETERS:
-- - search_term: TEXT - The search term to match against plant names
-- - result_limit: INTEGER - Maximum number of results to return (default 50)
-- - minimum_similarity: FLOAT - Minimum similarity threshold (default 0.25)
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
-- - similarity_score: FLOAT - Similarity score (0.0-1.0) for ranking
-- - matched_synonym: TEXT - Which synonym was matched (if any)
--
-- SEARCH BEHAVIOR:
-- - Uses PostgreSQL trigram similarity (pg_trgm) for fuzzy matching
-- - Sanitizes input using sanitize_plant_name() for consistency
-- - Splits synonyms by " | " and searches individual synonyms
-- - Calculates similarity scores for intelligent ranking
-- - Excludes synonym plants (synonym_to IS NULL)
-- - Supports typos and partial matches
-- - Prioritizes exact matches, then high similarity, then fuzzy matches
--
-- SIMILARITY SCORING:
-- - 1.0: Perfect exact match
-- - 0.9-0.99: Very close match (minor differences)
-- - 0.7-0.89: Good match (some differences)
-- - 0.5-0.69: Fuzzy match (moderate differences)
-- - 0.25-0.49: Loose match (significant differences but still relevant)
--
-- PERFORMANCE FEATURES:
-- - GIN trigram indexes for fast fuzzy search
-- - Pre-filtering with % operator to eliminate non-matches
-- - Optimized synonym splitting and scoring
-- - Intelligent result limiting
--
-- EXAMPLE USAGE:
-- SELECT * FROM search_all_plants('pinus');
-- SELECT * FROM search_all_plants('acer platonoid', 20, 0.3); -- With typo
-- SELECT * FROM search_all_plants('norway maple', 15); -- Common name
-- =====================================================================================

-- Ensure pg_trgm extension is available (required for trigram similarity)
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- =====================================================================================
DROP FUNCTION IF EXISTS search_all_plants_basic(search_term TEXT, result_limit INTEGER);
DROP FUNCTION IF EXISTS search_all_plants(search_term TEXT, result_limit INTEGER);

CREATE OR REPLACE FUNCTION search_all_plants(
    search_term TEXT,
    result_limit INTEGER DEFAULT 50,
    minimum_similarity FLOAT DEFAULT 0.25
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
    matched_synonym TEXT
) AS $$
DECLARE
    v_search_term_sanitized TEXT;
    v_result_limit INTEGER;
    v_min_similarity FLOAT;
BEGIN
    -- Validate and sanitize search term
    IF search_term IS NULL OR trim(search_term) = '' THEN
        RETURN;
    END IF;
    
    -- Sanitize the search term using centralized function
    v_search_term_sanitized := sanitize_plant_name(search_term);
    
    -- Return empty if sanitized term is too short
    IF v_search_term_sanitized IS NULL OR length(v_search_term_sanitized) < 2 THEN
        RETURN;
    END IF;
    
    -- Ensure reasonable limits for performance and user experience
    v_result_limit := LEAST(GREATEST(result_limit, 1), 100);
    v_min_similarity := GREATEST(minimum_similarity, 0.1);
    
    RETURN QUERY
    WITH similarity_scores AS (
        SELECT 
            f.id,
            f.name,
            f.sv_name,
            f.plant_type,
            f.has_synonyms,
            f.has_synonyms_id,
            f.user_submitted,
            f.created_by,
            
            -- Calculate the best similarity score from all possible matches
            GREATEST(
                -- Main scientific name similarity
                SIMILARITY(sanitize_plant_name(f.name), v_search_term_sanitized),
                
                -- Swedish/common name similarity
                CASE 
                    WHEN f.sv_name IS NOT NULL AND LENGTH(TRIM(f.sv_name)) > 0 THEN
                        SIMILARITY(sanitize_plant_name(f.sv_name), v_search_term_sanitized)
                    ELSE 0.0
                END,
                
                -- Individual synonym similarities (split by " | " separator)
                CASE 
                    WHEN f.has_synonyms IS NOT NULL AND LENGTH(f.has_synonyms) > 0 THEN
                        (SELECT MAX(SIMILARITY(sanitize_plant_name(TRIM(synonym)), v_search_term_sanitized))
                         FROM unnest(string_to_array(f.has_synonyms, ' | ')) AS synonym
                         WHERE LENGTH(TRIM(synonym)) > 0)
                    ELSE 0.0
                END
            ) AS best_similarity_score,
            
            -- Determine which synonym matched best (for user feedback)
            CASE 
                WHEN f.has_synonyms IS NOT NULL AND LENGTH(f.has_synonyms) > 0 THEN
                    (SELECT syn_data.synonym_name
                     FROM (
                         SELECT 
                             TRIM(synonym) AS synonym_name,
                             SIMILARITY(sanitize_plant_name(TRIM(synonym)), v_search_term_sanitized) AS sim_score
                         FROM unnest(string_to_array(f.has_synonyms, ' | ')) AS synonym
                         WHERE LENGTH(TRIM(synonym)) > 0
                     ) syn_data
                     WHERE syn_data.sim_score = (
                         SELECT MAX(SIMILARITY(sanitize_plant_name(TRIM(syn)), v_search_term_sanitized))
                         FROM unnest(string_to_array(f.has_synonyms, ' | ')) AS syn
                         WHERE LENGTH(TRIM(syn)) > 0
                     )
                     -- Only show matched synonym if it's better than main name match
                     AND syn_data.sim_score > SIMILARITY(sanitize_plant_name(f.name), v_search_term_sanitized)
                     AND syn_data.sim_score > SIMILARITY(sanitize_plant_name(COALESCE(f.sv_name, '')), v_search_term_sanitized)
                     AND syn_data.sim_score >= v_min_similarity
                     LIMIT 1)
                ELSE NULL
            END AS matched_synonym_name
            
        FROM facit f
        WHERE 
            -- Only include main plant entries (exclude synonyms)
            f.synonym_to IS NULL
            AND (
                -- Pre-filter using trigram % operator for performance
                -- This quickly eliminates obviously non-matching records
                sanitize_plant_name(f.name) % v_search_term_sanitized
                OR
                -- Check Swedish/common name if available
                (f.sv_name IS NOT NULL 
                 AND LENGTH(TRIM(f.sv_name)) > 0
                 AND sanitize_plant_name(f.sv_name) % v_search_term_sanitized)
                OR
                -- Check individual synonyms (split by " | ")
                (f.has_synonyms IS NOT NULL 
                 AND LENGTH(f.has_synonyms) > 0 
                 AND EXISTS(
                     SELECT 1 FROM unnest(string_to_array(f.has_synonyms, ' | ')) AS synonym
                     WHERE LENGTH(TRIM(synonym)) > 0 
                     AND sanitize_plant_name(TRIM(synonym)) % v_search_term_sanitized
                 ))
            )
    )
    SELECT 
        s.id,
        s.name,
        s.sv_name,
        s.plant_type,
        s.has_synonyms,
        s.has_synonyms_id,
        s.user_submitted,
        s.created_by,
        ROUND(s.best_similarity_score::numeric, 3)::FLOAT AS similarity_score,
        s.matched_synonym_name::TEXT AS matched_synonym
    FROM similarity_scores s
    WHERE s.best_similarity_score >= v_min_similarity
    ORDER BY 
        -- Primary: Best similarity score first
        s.best_similarity_score DESC,
        -- Secondary: Prefer shorter names (more specific results)
        LENGTH(s.name) ASC,
        -- Tertiary: Alphabetical order for consistency
        s.name ASC
    LIMIT v_result_limit;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Log error and return empty result set for graceful degradation
        RAISE WARNING 'Error in search_all_plants: %', SQLERRM;
        RETURN;
END;
$$ LANGUAGE plpgsql STABLE
SET client_encoding = 'UTF8';

-- =====================================================================================
-- Performance Optimization: Required Indexes for Advanced Search
-- =====================================================================================
-- 
-- These indexes are CRITICAL for performance with the trigram similarity search.
-- The GIN trigram indexes enable fast fuzzy matching on 170k+ plant records.
-- =====================================================================================

-- Trigram indexes for fuzzy search performance on main names
CREATE INDEX IF NOT EXISTS idx_facit_name_trigram_gin_all_plants
ON facit USING gin (sanitize_plant_name(name) gin_trgm_ops)
WHERE synonym_to IS NULL;

-- Trigram indexes for Swedish/common names  
CREATE INDEX IF NOT EXISTS idx_facit_sv_name_trigram_gin_all_plants
ON facit USING gin (sanitize_plant_name(sv_name) gin_trgm_ops)
WHERE synonym_to IS NULL AND sv_name IS NOT NULL AND LENGTH(TRIM(sv_name)) > 0;

-- Trigram indexes for synonym search (split by " | ")
CREATE INDEX IF NOT EXISTS idx_facit_synonyms_trigram_gin_all_plants
ON facit USING gin (sanitize_plant_name(has_synonyms) gin_trgm_ops)
WHERE synonym_to IS NULL AND has_synonyms IS NOT NULL AND LENGTH(has_synonyms) > 0;

-- Fast prefix search indexes (for autocomplete functionality)
CREATE INDEX IF NOT EXISTS idx_facit_name_prefix_all_plants
ON facit USING btree (sanitize_plant_name(name) text_pattern_ops)
WHERE synonym_to IS NULL;

CREATE INDEX IF NOT EXISTS idx_facit_sv_name_prefix_all_plants  
ON facit USING btree (sanitize_plant_name(sv_name) text_pattern_ops)
WHERE synonym_to IS NULL AND sv_name IS NOT NULL;

-- Composite index for filtering non-synonym plants
CREATE INDEX IF NOT EXISTS idx_facit_main_plants_filter_all_plants
ON facit (synonym_to, name)
WHERE synonym_to IS NULL;

-- =====================================================================================
-- Usage Examples and Performance Notes
-- =====================================================================================
-- 
-- Basic search with fuzzy matching:
-- SELECT * FROM search_all_plants('pinus cemba');
-- 
-- Search with custom similarity threshold:
-- SELECT * FROM search_all_plants('acer platonoid', 20, 0.3); -- Will match "Acer platanoides"
-- 
-- Handle typos and variations:
-- SELECT * FROM search_all_plants('norway maple', 15); -- Finds via synonyms
-- 
-- PERFORMANCE NOTES:
-- - The trigram indexes are essential for good performance
-- - Lower similarity thresholds will return more results but slower queries
-- - Consider caching frequent search terms on the client side
-- - Optimal similarity threshold for PlantPicker is 0.25-0.4
-- =====================================================================================
