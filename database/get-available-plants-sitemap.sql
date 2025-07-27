-- Database function to get all available plants for sitemap generation
-- This function fetches plants that are currently in stock at verified nurseries
-- Returns id, name, and last_edited for sitemap URL generation

CREATE OR REPLACE FUNCTION get_available_plants_sitemap()
RETURNS TABLE(
    id bigint,
    name text,
    last_edited timestamp with time zone
) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        f.id,
        f.name,
        f.last_edited
    FROM facit f
    INNER JOIN totallager tl ON f.id = tl.facit_id
    INNER JOIN plantskolor p ON tl.plantskola_id = p.id
    WHERE 
        -- Only include plants that are in stock
        (tl.stock IS NULL OR tl.stock > 0)
        -- Only include plants that are not hidden
        AND tl.hidden = false
        -- Only include nurseries that are not hidden
        AND p.hidden = false
        -- Only include verified nurseries
        AND p.verified = true
        -- Exclude synonyms - only include accepted names
        AND (f.synonym_to IS NULL OR f.synonym_to = '')
    ORDER BY f.last_edited DESC;
END;
$$ LANGUAGE plpgsql STABLE;
