-- Database function to get all verified nurseries for sitemap generation
-- This function fetches all verified nurseries that are publicly visible
-- Returns id, name, and last_edited for sitemap URL generation

CREATE OR REPLACE FUNCTION get_plantskolor_sitemap()
RETURNS TABLE(
    id bigint,
    name text,
    last_edited timestamp with time zone
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        p.name,
        p.last_edited
    FROM plantskolor p
    WHERE 
        -- Only include verified nurseries
        p.verified = true
        -- Only include nurseries that are not hidden
        AND p.hidden = false
    ORDER BY p.last_edited DESC;
END;
$$ LANGUAGE plpgsql STABLE;
