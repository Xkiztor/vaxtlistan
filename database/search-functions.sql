-- Enable pg_trgm extension for trigram similarity search
CREATE EXTENSION IF NOT EXISTS pg_trgm;
-- Enable unaccent extension for removing accents and special characters
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

-- Create optimized indexes for high-performance search on 170k+ rows
-- These indexes are crucial for fast search performance on the free tier

-- Composite index for efficient searches on normalized text
CREATE INDEX IF NOT EXISTS idx_facit_name_normalized 
ON facit (normalize_search_text(name) text_pattern_ops);

CREATE INDEX IF NOT EXISTS idx_facit_sv_name_normalized 
ON facit (normalize_search_text(sv_name) text_pattern_ops);

-- Covering index for search results (includes commonly selected columns)
CREATE INDEX IF NOT EXISTS idx_facit_search_covering 
ON facit (name, sv_name) 
INCLUDE (id, plant_type, rhs_types, is_synonym, synonym_to, rhs_hardiness, spread, height, colors, last_edited);

-- Function for ultra-fast prefix search (most efficient for short queries)
-- Now supports multi-word search: "juglans adams" finds "Juglans regia 'Adams'"
CREATE OR REPLACE FUNCTION search_plants_prefix(
  search_term text,
  result_limit integer DEFAULT 60,
  result_offset integer DEFAULT 0
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
  last_edited timestamptz
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
      f.last_edited
    FROM facit f
    WHERE ' || where_conditions || '
    ORDER BY 
      CASE 
        -- Prioritize prefix matches for scientific names
        WHEN normalize_search_text(f.name) LIKE $1 || ''%'' THEN 1
        -- Prioritize prefix matches for Swedish names
        WHEN normalize_search_text(f.sv_name) LIKE $1 || ''%'' THEN 2
        -- Then multi-word matches
        ELSE 3
      END,
      f.name
    LIMIT $2
    OFFSET $3'
  USING normalized_term, result_limit, result_offset;
END;
$$;

-- Function for substring search (for longer queries)
-- Now supports multi-word search with optimization for single-word queries
CREATE OR REPLACE FUNCTION search_plants_substring(
  search_term text,
  result_limit integer DEFAULT 60,
  result_offset integer DEFAULT 0
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
  last_edited timestamptz
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
  
  -- For single word, use simple substring search (faster)
  IF array_length(search_words, 1) = 1 THEN
    RETURN QUERY
    SELECT 
      f.id, f.name, f.sv_name, f.plant_type, f.rhs_types,
      f.is_synonym, f.synonym_to, f.rhs_hardiness, f.spread, 
      f.height, f.colors, f.last_edited
    FROM facit f
    WHERE 
      normalize_search_text(f.name) LIKE '%' || normalized_term || '%'
      OR normalize_search_text(f.sv_name) LIKE '%' || normalized_term || '%'
    ORDER BY 
      CASE 
        WHEN normalize_search_text(f.name) LIKE normalized_term || '%' THEN 1
        WHEN normalize_search_text(f.sv_name) LIKE normalized_term || '%' THEN 2
        WHEN normalize_search_text(f.name) LIKE '%' || normalized_term || '%' THEN 3
        WHEN normalize_search_text(f.sv_name) LIKE '%' || normalized_term || '%' THEN 4
        ELSE 5
      END,
      f.name
    LIMIT result_limit
    OFFSET result_offset;
    RETURN;
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
      f.last_edited
    FROM facit f
    WHERE ' || where_conditions || '
    ORDER BY 
      CASE 
        -- Prioritize prefix matches for scientific names
        WHEN normalize_search_text(f.name) LIKE $1 || ''%'' THEN 1
        -- Prioritize prefix matches for Swedish names
        WHEN normalize_search_text(f.sv_name) LIKE $1 || ''%'' THEN 2
        -- Then multi-word matches
        ELSE 3
      END,
      f.name
    LIMIT $2
    OFFSET $3'
  USING normalized_term, result_limit, result_offset;
END;
$$;

-- Efficient count function for search results
-- Now supports multi-word search to match the search behavior accurately
CREATE OR REPLACE FUNCTION count_search_results(
  search_term text,
  use_prefix boolean DEFAULT true
)
RETURNS bigint
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  result_count bigint;
  normalized_term text;
  search_words text[];
  word text;
  where_conditions text := '';
  name_conditions text := '';
  sv_name_conditions text := '';
BEGIN
  -- Normalize the search term and split into words
  normalized_term := normalize_search_text(search_term);
  search_words := string_to_array(trim(normalized_term), ' ');
  
  -- Remove empty strings from array
  search_words := array_remove(search_words, '');
  
  -- If no valid words, return 0
  IF array_length(search_words, 1) IS NULL THEN
    RETURN 0;
  END IF;
  
  -- For single word, use simple counting (faster)
  IF array_length(search_words, 1) = 1 THEN
    IF use_prefix THEN
      SELECT COUNT(*)
      INTO result_count
      FROM facit f
      WHERE 
        normalize_search_text(f.name) LIKE normalized_term || '%'
        OR normalize_search_text(f.sv_name) LIKE '%' || normalized_term || '%';
    ELSE
      SELECT COUNT(*)
      INTO result_count
      FROM facit f
      WHERE 
        normalize_search_text(f.name) LIKE '%' || normalized_term || '%'
        OR normalize_search_text(f.sv_name) LIKE '%' || normalized_term || '%';
    END IF;
    RETURN result_count;
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
  
  EXECUTE 'SELECT COUNT(*) FROM facit f WHERE ' || where_conditions INTO result_count;
  
  RETURN result_count;
END;
$$;

-- Advanced trigram similarity search (use sparingly on free tier)
-- Now ignores special characters and accents
CREATE OR REPLACE FUNCTION search_plants_similarity(
  search_term text,
  similarity_threshold real DEFAULT 0.3,
  result_limit integer DEFAULT 60,
  result_offset integer DEFAULT 0
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
  similarity_score real
) 
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  normalized_term text;
BEGIN
  -- Normalize the search term
  normalized_term := normalize_search_text(search_term);
  
  RETURN QUERY
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
    GREATEST(
      similarity(normalize_search_text(f.name), normalized_term),
      similarity(normalize_search_text(f.sv_name), normalized_term)
    ) as similarity_score
  FROM facit f
  WHERE 
    similarity(normalize_search_text(f.name), normalized_term) > similarity_threshold
    OR similarity(normalize_search_text(f.sv_name), normalized_term) > similarity_threshold
  ORDER BY similarity_score DESC, f.name
  LIMIT result_limit
  OFFSET result_offset;
END;
$$;
