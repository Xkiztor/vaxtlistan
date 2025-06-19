-- Fast similarity search function for plant names
-- Uses PostgreSQL's built-in similarity functions for efficient fuzzy matching
-- Optimized for scientific plant names with proper indexing

-- First, ensure pg_trgm extension is enabled (required for similarity functions)
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Optimized similarity search function for plant names
-- Designed for performance on large datasets (170k+ rows) with limited resources
-- Prioritizes speed while maintaining good accuracy
CREATE OR REPLACE FUNCTION search_plants_similarity_fast(
  search_term TEXT,
  similarity_threshold REAL DEFAULT 0.3,
  result_limit INTEGER DEFAULT 10,
  result_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
  id BIGINT,
  name TEXT,
  sv_name TEXT,
  similarity_score REAL
)
LANGUAGE plpgsql
AS $$
BEGIN
  -- Normalize search term
  search_term := LOWER(TRIM(search_term));
  
  -- Return early if search term is too short
  IF LENGTH(search_term) < 2 THEN
    RETURN;
  END IF;

  -- Adjust threshold for shorter terms to reduce false positives
  IF LENGTH(search_term) < 8 THEN
    similarity_threshold := GREATEST(similarity_threshold, 0.4);
  END IF;

  -- Single-pass query optimized for performance
  -- Uses simple pattern matching first (fast with indexes) then trigram similarity
  RETURN QUERY
  SELECT 
    f.id,
    f.name,
    f.sv_name,
    -- Simplified scoring for better performance
    CASE 
      -- Exact match (highest priority)
      WHEN LOWER(f.name) = search_term THEN 1.0
      -- Prefix match (very good for genus matching)
      WHEN LOWER(f.name) LIKE search_term || '%' THEN 0.9
      -- Word boundary match (good for species in genus)
      WHEN LOWER(f.name) LIKE '% ' || search_term || '%' 
        OR LOWER(f.name) LIKE '%' || search_term || ' %' THEN 0.8
      -- Use trigram similarity only for remaining cases (more expensive)
      ELSE COALESCE(similarity(search_term, LOWER(f.name)), 0.0)
    END AS similarity_score
  FROM facit f
  WHERE 
    f.name IS NOT NULL 
    AND LENGTH(f.name) > 0
    AND (
      -- Fast pattern matches first (uses indexes efficiently)
      LOWER(f.name) = search_term
      OR LOWER(f.name) LIKE search_term || '%'
      OR (
        LENGTH(search_term) >= 4 AND (
          LOWER(f.name) LIKE '% ' || search_term || '%'
          OR LOWER(f.name) LIKE '%' || search_term || ' %'
          OR LOWER(f.name) LIKE '%' || search_term || '%'
        )
      )
      -- Only use expensive trigram similarity for non-matching cases
      OR (
        LENGTH(search_term) >= 5 
        AND similarity(search_term, LOWER(f.name)) > similarity_threshold
      )
    )
  ORDER BY 
    -- Simple scoring for fast sorting
    CASE 
      WHEN LOWER(f.name) = search_term THEN 1.0
      WHEN LOWER(f.name) LIKE search_term || '%' THEN 0.9
      WHEN LOWER(f.name) LIKE '% ' || search_term || '%' 
        OR LOWER(f.name) LIKE '%' || search_term || ' %' THEN 0.8
      ELSE COALESCE(similarity(search_term, LOWER(f.name)), 0.0)
    END DESC,
    LENGTH(f.name) ASC
  LIMIT result_limit
  OFFSET result_offset;
END;
$$;

-- Optimized fallback function for systems without pg_trgm
-- Simple and fast pattern matching for large datasets
CREATE OR REPLACE FUNCTION search_plants_similarity_basic(
  search_term TEXT,
  result_limit INTEGER DEFAULT 10,
  result_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
  id BIGINT,
  name TEXT,
  sv_name TEXT,
  similarity_score REAL
)
LANGUAGE plpgsql
AS $$
DECLARE
  min_threshold REAL := 0.3;
BEGIN
  -- Normalize search term
  search_term := LOWER(TRIM(search_term));
  
  -- Return early if search term is too short
  IF LENGTH(search_term) < 2 THEN
    RETURN;
  END IF;

  -- Adjust threshold for shorter search terms
  IF LENGTH(search_term) < 8 THEN
    min_threshold := 0.4;
  END IF;

  -- Simple and fast pattern-based search
  RETURN QUERY
  SELECT 
    f.id,
    f.name,
    f.sv_name,
    CASE 
      -- Exact match
      WHEN LOWER(f.name) = search_term THEN 1.0
      -- Prefix match
      WHEN LOWER(f.name) LIKE search_term || '%' THEN 0.9
      -- Word boundary match (space separated)
      WHEN LOWER(f.name) LIKE '% ' || search_term || '%' 
        OR LOWER(f.name) LIKE '%' || search_term || ' %' THEN 0.8
      -- Substring match
      WHEN LOWER(f.name) LIKE '%' || search_term || '%' THEN 0.7
      ELSE 0.0
    END AS similarity_score
  FROM facit f
  WHERE 
    f.name IS NOT NULL
    AND LENGTH(f.name) > 0
    AND (
      -- Direct matches (uses indexes efficiently)
      LOWER(f.name) = search_term
      OR LOWER(f.name) LIKE search_term || '%'
      OR (
        LENGTH(search_term) >= 4 AND (
          LOWER(f.name) LIKE '% ' || search_term || '%'
          OR LOWER(f.name) LIKE '%' || search_term || ' %'
          OR LOWER(f.name) LIKE '%' || search_term || '%'
        )
      )
    )
    -- Apply minimum similarity threshold
    AND CASE 
      WHEN LOWER(f.name) = search_term THEN 1.0
      WHEN LOWER(f.name) LIKE search_term || '%' THEN 0.9
      WHEN LOWER(f.name) LIKE '% ' || search_term || '%' 
        OR LOWER(f.name) LIKE '%' || search_term || ' %' THEN 0.8
      WHEN LOWER(f.name) LIKE '%' || search_term || '%' THEN 0.7
      ELSE 0.0
    END >= min_threshold
  ORDER BY 
    -- Order by similarity score descending
    CASE 
      WHEN LOWER(f.name) = search_term THEN 1.0
      WHEN LOWER(f.name) LIKE search_term || '%' THEN 0.9
      WHEN LOWER(f.name) LIKE '% ' || search_term || '%' 
        OR LOWER(f.name) LIKE '%' || search_term || ' %' THEN 0.8
      WHEN LOWER(f.name) LIKE '%' || search_term || '%' THEN 0.7
      ELSE 0.0
    END DESC,
    LENGTH(f.name) ASC
  LIMIT result_limit
  OFFSET result_offset;
END;
$$;

-- Create indexes to support the similarity searches
CREATE INDEX IF NOT EXISTS facit_name_gin_trgm ON facit USING GIN (LOWER(name) gin_trgm_ops);
CREATE INDEX IF NOT EXISTS facit_name_lower_prefix ON facit (LOWER(name) text_pattern_ops);
CREATE INDEX IF NOT EXISTS facit_name_lower_btree ON facit (LOWER(name));

-- Comments
COMMENT ON FUNCTION search_plants_similarity_fast IS 'Performance-optimized similarity search for plant names. Uses efficient pattern matching with trigram similarity as fallback. Designed for large datasets (170k+ rows) on resource-constrained environments like Supabase free tier.';
COMMENT ON FUNCTION search_plants_similarity_basic IS 'Fast pattern-based similarity search for plant names. Optimized for performance over accuracy, suitable for large datasets without pg_trgm extension.';
