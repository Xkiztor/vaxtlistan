-- Search functions for search page and inline search
-- These functions only return plants that exist somewhere in totallager (available plants)
-- Much faster since it searches a smaller dataset of plants that are actually available

DROP FUNCTION IF EXISTS search_available_plants_prefix(text,integer,integer,boolean);
DROP FUNCTION IF EXISTS search_available_plants_substring(text,integer,integer,boolean);
DROP FUNCTION IF EXISTS search_available_plants_similarity(text,real,integer,integer,boolean);
DROP FUNCTION IF EXISTS search_available_plants(text,integer,integer,boolean,boolean);

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS unaccent;

-- Create a function to normalize text by removing special characters and accents
CREATE OR REPLACE FUNCTION normalize_search_text(input_text text)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  -- Remove accents, convert to lowercase, and remove special characters except spaces
  RETURN regexp_replace(
    lower(unaccent(input_text)), 
    '[^a-z0-9\s]', 
    '', 
    'g'
  );
END;
$$;

-- Create optimized indexes for searching available plants
-- These indexes focus on the join between facit and totallager for performance
CREATE INDEX IF NOT EXISTS idx_totallager_facit_id ON totallager (facit_id);
CREATE INDEX IF NOT EXISTS idx_totallager_hidden ON totallager (hidden);
CREATE INDEX IF NOT EXISTS idx_totallager_facit_hidden ON totallager (facit_id, hidden);

-- Simple normalized search indexes for facit table
CREATE INDEX IF NOT EXISTS idx_facit_name_normalized 
ON facit USING GIN (normalize_search_text(name) gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_facit_sv_name_normalized 
ON facit USING GIN (normalize_search_text(sv_name) gin_trgm_ops);

-- Composite index for efficient name searches
CREATE INDEX IF NOT EXISTS idx_facit_both_names_normalized
ON facit USING GIN ((normalize_search_text(name) || ' ' || COALESCE(normalize_search_text(sv_name), '')) gin_trgm_ops);

-- Function for ultra-fast prefix search on AVAILABLE plants only
-- Used by search page and inline search components
CREATE OR REPLACE FUNCTION search_available_plants_prefix(
  search_term text,
  result_limit integer DEFAULT 60,
  result_offset integer DEFAULT 0,
  include_hidden boolean DEFAULT false
)
RETURNS TABLE(
  id bigint,
  name text,
  sv_name text,
  plant_type text,
  rhs_types smallint[],
  is_synonym boolean,
  synonym_to text,
  rhs_hardiness bigint,
  spread text,
  height text,
  colors text[],
  last_edited timestamptz,
  available_count bigint,
  plantskolor_count bigint,
  prices numeric[]
) 
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  normalized_term text;
  search_words text[];
  word text;
  where_conditions text := '';
  name_conditions text := '';
  sv_name_conditions text := '';
  hidden_condition text := '';
BEGIN
  -- Normalize the search term and split into words
  normalized_term := normalize_search_text(search_term);
  search_words := string_to_array(trim(normalized_term), ' ');
  
  -- Remove empty strings from array
  search_words := array_remove(search_words, '');
  
  -- If no valid words, return empty
  IF array_length(search_words, 1) IS NULL THEN
    RETURN;
  END IF;
  
  -- Set hidden condition
  IF NOT include_hidden THEN
    hidden_condition := 'AND NOT tl.hidden';
  END IF;
  
  -- Build conditions for each word to match in scientific names
  FOREACH word IN ARRAY search_words
  LOOP
    IF name_conditions != '' THEN
      name_conditions := name_conditions || ' AND ';
    END IF;
    name_conditions := name_conditions || 'normalize_search_text(f.name) LIKE ''%' || word || '%''';
  END LOOP;
  
  -- Build conditions for each word to match in Swedish names
  FOREACH word IN ARRAY search_words
  LOOP
    IF sv_name_conditions != '' THEN
      sv_name_conditions := sv_name_conditions || ' AND ';
    END IF;
    sv_name_conditions := sv_name_conditions || 'normalize_search_text(f.sv_name) LIKE ''%' || word || '%''';
  END LOOP;
  
  -- Combine conditions
  where_conditions := '(' || name_conditions || ') OR (' || sv_name_conditions || ')';
    RETURN QUERY EXECUTE '
    SELECT 
      f.id,
      f.name,
      f.sv_name,
      f.plant_type,
      f.rhs_types,
      f.is_synonym,
      f.synonym_to,
      f.rhs_hardiness,
      f.spread,
      f.height,
      f.colors,
      f.last_edited,
      COUNT(tl.id) as available_count,
      COUNT(DISTINCT tl.plantskola_id) as plantskolor_count,
      array_agg(DISTINCT tl.price ORDER BY tl.price) FILTER (WHERE tl.price IS NOT NULL) as prices
    FROM facit f
    INNER JOIN totallager tl ON f.id = tl.facit_id
    INNER JOIN plantskolor p ON tl.plantskola_id = p.id
    WHERE (' || where_conditions || ') ' || hidden_condition || '
      AND p.verified = true
      AND NOT p.hidden
    GROUP BY f.id, f.name, f.sv_name, f.plant_type, f.rhs_types, 
             f.is_synonym, f.synonym_to, f.rhs_hardiness, f.spread, 
             f.height, f.colors, f.last_edited
    ORDER BY 
      CASE 
        -- Prioritize prefix matches for scientific names
        WHEN normalize_search_text(f.name) LIKE $1 || ''%'' THEN 1
        -- Prioritize prefix matches for Swedish names
        WHEN normalize_search_text(f.sv_name) LIKE $1 || ''%'' THEN 2
        -- Then multi-word matches
        ELSE 3
      END,
      available_count DESC,
      f.name
    LIMIT $2
    OFFSET $3'
  USING normalized_term, result_limit, result_offset;
END;
$$;

-- Function for substring search on AVAILABLE plants only
-- Used by search page and inline search for longer/more complex queries
CREATE OR REPLACE FUNCTION search_available_plants_substring(
  search_term text,
  result_limit integer DEFAULT 60,
  result_offset integer DEFAULT 0,
  include_hidden boolean DEFAULT false
)
RETURNS TABLE(
  id bigint,
  name text,
  sv_name text,
  plant_type text,
  rhs_types smallint[],
  is_synonym boolean,
  synonym_to text,
  rhs_hardiness bigint,
  spread text,
  height text,
  colors text[],
  last_edited timestamptz,
  available_count bigint,
  plantskolor_count bigint,
  prices numeric[]
) 
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  normalized_term text;
  search_words text[];
  word text;
  where_conditions text := '';
  name_conditions text := '';
  sv_name_conditions text := '';
  hidden_condition text := '';
BEGIN
  -- Normalize the search term and split into words
  normalized_term := normalize_search_text(search_term);
  search_words := string_to_array(trim(normalized_term), ' ');
  
  -- Remove empty strings from array
  search_words := array_remove(search_words, '');
  
  -- If no valid words, return empty
  IF array_length(search_words, 1) IS NULL THEN
    RETURN;
  END IF;
  
  -- Set hidden condition
  IF NOT include_hidden THEN
    hidden_condition := 'AND NOT tl.hidden';
  END IF;
  
  -- Build conditions for each word to match in scientific names
  FOREACH word IN ARRAY search_words
  LOOP
    IF name_conditions != '' THEN
      name_conditions := name_conditions || ' AND ';
    END IF;
    name_conditions := name_conditions || 'normalize_search_text(f.name) LIKE ''%' || word || '%''';
  END LOOP;
  
  -- Build conditions for each word to match in Swedish names
  FOREACH word IN ARRAY search_words
  LOOP
    IF sv_name_conditions != '' THEN
      sv_name_conditions := sv_name_conditions || ' AND ';
    END IF;
    sv_name_conditions := sv_name_conditions || 'normalize_search_text(f.sv_name) LIKE ''%' || word || '%''';
  END LOOP;
  
  -- Combine conditions
  where_conditions := '(' || name_conditions || ') OR (' || sv_name_conditions || ')';    RETURN QUERY EXECUTE '
    SELECT 
      f.id,
      f.name,
      f.sv_name,
      f.plant_type,
      f.rhs_types,
      f.is_synonym,
      f.synonym_to,
      f.rhs_hardiness,
      f.spread,
      f.height,
      f.colors,
      f.last_edited,
      COUNT(tl.id) as available_count,
      COUNT(DISTINCT tl.plantskola_id) as plantskolor_count,
      array_agg(DISTINCT tl.price ORDER BY tl.price) FILTER (WHERE tl.price IS NOT NULL) as prices
    FROM facit f
    INNER JOIN totallager tl ON f.id = tl.facit_id
    INNER JOIN plantskolor p ON tl.plantskola_id = p.id
    WHERE (' || where_conditions || ') ' || hidden_condition || '
      AND p.verified = true
      AND NOT p.hidden
    GROUP BY f.id, f.name, f.sv_name, f.plant_type, f.rhs_types, 
             f.is_synonym, f.synonym_to, f.rhs_hardiness, f.spread, 
             f.height, f.colors, f.last_edited
    ORDER BY 
      -- Use length for basic relevance scoring
      LENGTH(f.name) ASC,
      available_count DESC,
      f.name
    LIMIT $1
    OFFSET $2'
  USING result_limit, result_offset;
END;
$$;

-- Function for similarity search on AVAILABLE plants only  
-- Uses fuzzy matching for typos and similar terms
CREATE OR REPLACE FUNCTION search_available_plants_similarity(
  search_term text,
  similarity_threshold real DEFAULT 0.2,
  result_limit integer DEFAULT 60,
  result_offset integer DEFAULT 0,
  include_hidden boolean DEFAULT false
)
RETURNS TABLE(
  id bigint,
  name text,
  sv_name text,
  plant_type text,
  rhs_types smallint[],
  is_synonym boolean,
  synonym_to text,
  rhs_hardiness bigint,
  spread text,
  height text,
  colors text[],
  last_edited timestamptz,
  available_count bigint,
  plantskolor_count bigint,
  prices numeric[],
  similarity_score real
) 
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  normalized_term text;
  hidden_condition text := '';
BEGIN
  -- Normalize the search term
  normalized_term := normalize_search_text(search_term);
  
  -- Set similarity threshold for this session (lower threshold for better fuzzy matching)
  PERFORM set_limit(similarity_threshold);
  
  -- Set hidden condition
  IF NOT include_hidden THEN
    hidden_condition := 'AND NOT tl.hidden';
  END IF;
    RETURN QUERY EXECUTE '
    SELECT 
      f.id,
      f.name,
      f.sv_name,
      f.plant_type,
      f.rhs_types,
      f.is_synonym,
      f.synonym_to,
      f.rhs_hardiness,
      f.spread,
      f.height,
      f.colors,
      f.last_edited,
      COUNT(tl.id) as available_count,
      COUNT(DISTINCT tl.plantskola_id) as plantskolor_count,
      array_agg(DISTINCT tl.price ORDER BY tl.price) FILTER (WHERE tl.price IS NOT NULL) as prices,
      GREATEST(
        similarity(normalize_search_text(f.name), $1),
        COALESCE(similarity(normalize_search_text(f.sv_name), $1), 0)
      ) as similarity_score
    FROM facit f
    INNER JOIN totallager tl ON f.id = tl.facit_id
    INNER JOIN plantskolor p ON tl.plantskola_id = p.id
    WHERE (
      similarity(normalize_search_text(f.name), $1) > $2
      OR similarity(normalize_search_text(f.sv_name), $1) > $2
    ) ' || hidden_condition || '
      AND p.verified = true
      AND NOT p.hidden
    GROUP BY f.id, f.name, f.sv_name, f.plant_type, f.rhs_types, 
             f.is_synonym, f.synonym_to, f.rhs_hardiness, f.spread, 
             f.height, f.colors, f.last_edited
    ORDER BY
      similarity_score DESC,
      available_count DESC,
      f.name
    LIMIT $3
    OFFSET $4'
  USING normalized_term, similarity_threshold, result_limit, result_offset;
END;
$$;

-- Wrapper function to combine different search strategies for AVAILABLE plants
-- This is the main search function that should be called from the application
CREATE OR REPLACE FUNCTION search_available_plants(
  search_term text,
  result_limit integer DEFAULT 60,
  result_offset integer DEFAULT 0,
  include_hidden boolean DEFAULT false,
  use_fuzzy boolean DEFAULT true
)
RETURNS TABLE(
  id bigint,
  name text,
  sv_name text,
  plant_type text,
  rhs_types smallint[],
  is_synonym boolean,
  synonym_to text,
  rhs_hardiness bigint,
  spread text,
  height text,
  colors text[],
  last_edited timestamptz,
  available_count bigint,
  plantskolor_count bigint,
  prices numeric[],
  similarity_score real
) 
LANGUAGE plpgsql
STABLE
AS $$
BEGIN  -- If fuzzy search is enabled and we have a reasonable term, use similarity search
  IF use_fuzzy AND length(trim(search_term)) >= 3 THEN
    RETURN QUERY 
    SELECT * FROM search_available_plants_similarity(
      search_term, 
      0.2, -- Lower similarity threshold for better fuzzy matching
      result_limit, 
      result_offset, 
      include_hidden
    );
    
    -- If we got results, return them
    IF FOUND THEN
      RETURN;
    END IF;
  END IF;
  
  -- Try prefix search first (fastest for short terms)
  IF length(trim(search_term)) <= 20 THEN
    RETURN QUERY 
    SELECT 
      p.*,
      1.0::real as similarity_score
    FROM search_available_plants_prefix(
      search_term, 
      result_limit, 
      result_offset, 
      include_hidden
    ) p;
    
    -- If we got results, return them
    IF FOUND THEN
      RETURN;
    END IF;
  END IF;
  
  -- Fall back to substring search
  RETURN QUERY 
  SELECT 
    s.*,
    0.8::real as similarity_score
  FROM search_available_plants_substring(
    search_term, 
    result_limit, 
    result_offset, 
    include_hidden
  ) s;
END;
$$;
