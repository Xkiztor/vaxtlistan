-- Compress colors data from JSON objects to string format
-- Converts from: [{"colour": 8, "season": 3, "attributeType": 1}]
-- To: ["8-3-1"]

-- First, let's analyze the current data size
SELECT 
    pg_size_pretty(pg_total_relation_size('facit')) as table_size,
    COUNT(*) as total_rows,
    AVG(pg_column_size(colors)) as avg_colors_size,
    MAX(pg_column_size(colors)) as max_colors_size,
    MIN(pg_column_size(colors)) as min_colors_size
FROM facit 
WHERE colors IS NOT NULL;

-- Create a backup of the original colors column
ALTER TABLE facit ADD COLUMN colors_backup jsonb[];

-- Copy original data to backup
UPDATE facit SET colors_backup = colors;

-- Function to convert JSON object to compressed string
CREATE OR REPLACE FUNCTION compress_color_object(color_obj jsonb)
RETURNS text AS $$
BEGIN
    RETURN CONCAT(
        color_obj->>'colour', 
        '-', 
        color_obj->>'season', 
        '-', 
        color_obj->>'attributeType'
    );
END;
$$ LANGUAGE plpgsql;

-- Update the original colors column directly with compressed string arrays
UPDATE facit 
SET colors = (
    SELECT array_agg(to_jsonb(compress_color_object(color_element)))
    FROM unnest(colors_backup) as color_element
)
WHERE colors_backup IS NOT NULL AND array_length(colors_backup, 1) > 0;

-- Analysis after compression
SELECT 
    'Original JSONB' as format,
    AVG(pg_column_size(colors_backup)) as avg_size,
    MAX(pg_column_size(colors_backup)) as max_size,
    SUM(pg_column_size(colors_backup)) as total_size
FROM facit 
WHERE colors_backup IS NOT NULL

UNION ALL

SELECT 
    'Compressed Strings' as format,
    AVG(pg_column_size(colors)) as avg_size,
    MAX(pg_column_size(colors)) as max_size,
    SUM(pg_column_size(colors)) as total_size
FROM facit 
WHERE colors IS NOT NULL;

-- Calculate space savings
WITH size_comparison AS (
    SELECT 
        SUM(pg_column_size(colors_backup)) as original_size,
        SUM(pg_column_size(colors)) as compressed_size,
        COUNT(*) as row_count
    FROM facit 
    WHERE colors_backup IS NOT NULL AND colors IS NOT NULL
)
SELECT 
    original_size,
    compressed_size,
    original_size - compressed_size as bytes_saved,
    ROUND(((original_size - compressed_size)::numeric / original_size * 100), 2) as percent_saved,
    pg_size_pretty(original_size - compressed_size) as readable_savings
FROM size_comparison;

-- Sample the results to verify compression worked correctly
SELECT 
    colors_backup[1:2] as original_sample,
    colors[1:2] as compressed_sample
FROM facit 
WHERE colors_backup IS NOT NULL 
AND array_length(colors_backup, 1) >= 2
LIMIT 5;

-- Clean up backup after verification (UNCOMMENT AFTER TESTING):
-- ALTER TABLE facit DROP COLUMN colors_backup;

-- Drop the helper function
DROP FUNCTION compress_color_object(jsonb);

-- Function to decompress a single color string back to components (for application use)
CREATE OR REPLACE FUNCTION decompress_color_string(color_str text)
RETURNS TABLE(colour integer, season integer, attribute_type integer) AS $$
DECLARE
    parts text[];
BEGIN
    parts := string_to_array(color_str, '-');
    RETURN QUERY SELECT 
        parts[1]::integer as colour,
        parts[2]::integer as season,
        parts[3]::integer as attribute_type;
END;
$$ LANGUAGE plpgsql;

-- Convert colors to text array and remove quotes
ALTER TABLE facit ADD COLUMN colors_text text[];

UPDATE facit 
SET colors_text = (
    SELECT array_agg(replace(color_element::text, '"', ''))
    FROM unnest(colors) as color_element
)
WHERE colors IS NOT NULL;

-- Drop the original colors column and rename the text version
ALTER TABLE facit DROP COLUMN colors;
ALTER TABLE facit RENAME COLUMN colors_text TO colors;

-- Example queries to work with compressed format:

-- Query 1: Find plants with specific color in specific season
-- SELECT * FROM facit 
-- WHERE colors @> ARRAY['8-3-1']::text[]; -- Orange in Autumn for attributeType 1

-- Query 2: Find plants with any orange color (color ID 8)
-- SELECT * FROM facit 
-- WHERE EXISTS (
--     SELECT 1 FROM unnest(colors) as color_str 
--     WHERE color_str LIKE '8-%'
-- );

-- Query 3: Extract all unique color-season combinations
-- SELECT DISTINCT unnest(colors) as color_combination
-- FROM facit 
-- WHERE colors IS NOT NULL
-- ORDER BY color_combination;
