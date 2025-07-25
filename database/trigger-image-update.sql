CREATE OR REPLACE FUNCTION validate_facit_image_update()
RETURNS trigger AS $$
DECLARE
    -- A list of allowed columns for regular users
    allowed_columns text[] := ARRAY[
        'images',
        'images_reordered',
        'images_added_date'
    ];

    -- Changed columns in the update
    changed_columns text[];
    -- Loop variable for iterating through changed columns
    col text;
    -- Current user ID
    current_user_id uuid;
    -- Check if user is superadmin
    is_superadmin boolean := false;
BEGIN
    -- Get current user ID
    current_user_id := auth.uid();
    
    -- Check if current user is a superadmin
    IF current_user_id IS NOT NULL THEN
        SELECT EXISTS(
            SELECT 1 
            FROM superadmins 
            WHERE user_id = current_user_id
        ) INTO is_superadmin;
    END IF;
    
    -- If user is superadmin, allow all column updates
    IF is_superadmin THEN
        RETURN NEW;
    END IF;

    -- For regular users, check allowed columns
    -- Get list of actually changed columns using hstore diff
    changed_columns := akeys(hstore(NEW) - hstore(OLD));

    -- Loop through changed columns and reject if any are not in allowed list
    FOREACH col IN ARRAY changed_columns LOOP
        IF NOT (col = ANY(allowed_columns)) THEN
            RAISE EXCEPTION 'Column "%" is not allowed to be updated', col;
        END IF;
    END LOOP;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS facit_image_update_only_trigger ON facit;

CREATE TRIGGER facit_image_update_only_trigger
    BEFORE UPDATE ON facit
    FOR EACH ROW
    EXECUTE FUNCTION validate_facit_image_update();

