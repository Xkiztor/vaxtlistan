-- =====================================================================================
-- Function: sanitize_plant_name(input_name)
-- =====================================================================================
-- 
-- PURPOSE:
-- Centralized plant name sanitization function used by all search functions.
-- Normalizes plant names for consistent case-insensitive and special character 
-- insensitive searching across the platform.
--
-- PARAMETERS:
-- - input_name: TEXT - The plant name to sanitize
--
-- RETURNS:
-- TEXT - Sanitized plant name ready for searching
--
-- SANITIZATION RULES:
-- 1. Convert to lowercase for case-insensitive matching
-- 2. Remove or normalize special characters (', ", -, etc.)
-- 3. Handle Swedish characters (å, ä, ö)
-- 4. Remove extra whitespace and normalize spaces
-- 5. Handle common botanical name variations
-- 6. Normalize quotation marks around cultivar names
--
-- PERFORMANCE CONSIDERATIONS:
-- - This function will be called frequently in search operations
-- - Keep operations minimal and efficient
-- - Consider creating an index on sanitized names if used heavily
--
-- EXAMPLE TRANSFORMATIONS:
-- "Pinus cembra 'Stricta'" → "pinus cembra stricta"
-- "Acer platanoïdes" → "acer platanoides"
-- "Rosa  'Queen  Elizabeth'" → "rosa queen elizabeth"
--
-- EXAMPLE USAGE:
-- SELECT sanitize_plant_name('Pinus cembra ''Stricta''');
--
-- TODO FOR AI IMPLEMENTATION:
-- 1. Handle case conversion (LOWER function)
-- 2. Remove/normalize special characters using REGEXP_REPLACE
-- 3. Handle Swedish characters (å→a, ä→a, ö→o)
-- 4. Normalize multiple spaces to single spaces
-- 5. Trim leading/trailing whitespace
-- 6. Handle various quote styles (' " ` ´)
-- 7. Consider unaccent extension for broader character normalization
-- 8. Test with various botanical name formats
-- =====================================================================================

-- =====================================================================================
-- Function: sanitize_plant_name(input_name)
-- =====================================================================================

CREATE OR REPLACE FUNCTION sanitize_plant_name(input_name TEXT)
RETURNS TEXT AS $$
DECLARE
    sanitized_name TEXT;
BEGIN
    -- Handle NULL input
    IF input_name IS NULL THEN
        RETURN NULL;
    END IF;
    
    -- Start with the input name
    sanitized_name := input_name;
    
    -- Step 1: Convert to lowercase for case-insensitive matching
    sanitized_name := LOWER(sanitized_name);
    
    -- Step 2: Handle Swedish characters (å→a, ä→a, ö→o)
    sanitized_name := REPLACE(sanitized_name, 'å', 'a');
    sanitized_name := REPLACE(sanitized_name, 'ä', 'a');
    sanitized_name := REPLACE(sanitized_name, 'ö', 'o');
    
    -- Step 3: Handle other accented characters
    sanitized_name := REPLACE(sanitized_name, 'é', 'e');
    sanitized_name := REPLACE(sanitized_name, 'è', 'e');
    sanitized_name := REPLACE(sanitized_name, 'ê', 'e');
    sanitized_name := REPLACE(sanitized_name, 'ë', 'e');
    sanitized_name := REPLACE(sanitized_name, 'à', 'a');
    sanitized_name := REPLACE(sanitized_name, 'á', 'a');
    sanitized_name := REPLACE(sanitized_name, 'â', 'a');
    sanitized_name := REPLACE(sanitized_name, 'ã', 'a');
    sanitized_name := REPLACE(sanitized_name, 'ì', 'i');
    sanitized_name := REPLACE(sanitized_name, 'í', 'i');
    sanitized_name := REPLACE(sanitized_name, 'î', 'i');
    sanitized_name := REPLACE(sanitized_name, 'ï', 'i');
    sanitized_name := REPLACE(sanitized_name, 'ò', 'o');
    sanitized_name := REPLACE(sanitized_name, 'ó', 'o');
    sanitized_name := REPLACE(sanitized_name, 'ô', 'o');
    sanitized_name := REPLACE(sanitized_name, 'õ', 'o');
    sanitized_name := REPLACE(sanitized_name, 'ù', 'u');
    sanitized_name := REPLACE(sanitized_name, 'ú', 'u');
    sanitized_name := REPLACE(sanitized_name, 'û', 'u');
    sanitized_name := REPLACE(sanitized_name, 'ü', 'u');
    sanitized_name := REPLACE(sanitized_name, 'ç', 'c');
    sanitized_name := REPLACE(sanitized_name, 'ñ', 'n');
    
    -- Step 4: Remove/normalize quotation marks around cultivar names
    -- Handle various quote styles (' " ` ´)
    sanitized_name := REGEXP_REPLACE(sanitized_name, '[''"`´]', '', 'g');
    
    -- Step 5: Remove other special characters and punctuation
    -- Keep letters, numbers, spaces, and basic punctuation for botanical names
    sanitized_name := REGEXP_REPLACE(sanitized_name, '[^\w\s\-\.]', '', 'g');
    
    -- Step 6: Normalize hyphens and dots
    sanitized_name := REPLACE(sanitized_name, '–', '-'); -- en dash
    sanitized_name := REPLACE(sanitized_name, '—', '-'); -- em dash
    
    -- Step 7: Normalize multiple spaces to single spaces
    sanitized_name := REGEXP_REPLACE(sanitized_name, '\s+', ' ', 'g');
    
    -- Step 8: Trim leading and trailing whitespace
    sanitized_name := TRIM(sanitized_name);
    
    -- Return the sanitized name
    RETURN sanitized_name;
    
EXCEPTION
    WHEN OTHERS THEN        -- If any error occurs, return the original input in lowercase
        RETURN LOWER(TRIM(input_name));
END;
$$ LANGUAGE plpgsql IMMUTABLE
SET client_encoding = 'UTF8';

-- =====================================================================================
-- Alternative version using unaccent extension (more comprehensive)
-- Uncomment if unaccent extension is available
-- =====================================================================================

/*
-- Enable unaccent extension (requires superuser privileges)
-- CREATE EXTENSION IF NOT EXISTS unaccent;

CREATE OR REPLACE FUNCTION sanitize_plant_name_with_unaccent(input_name TEXT)
RETURNS TEXT AS $$
DECLARE
    sanitized_name TEXT;
BEGIN
    -- Handle NULL input
    IF input_name IS NULL THEN
        RETURN NULL;
    END IF;
    
    -- Start with the input name
    sanitized_name := input_name;
    
    -- Step 1: Convert to lowercase
    sanitized_name := LOWER(sanitized_name);
    
    -- Step 2: Remove accents using unaccent extension
    sanitized_name := unaccent(sanitized_name);
    
    -- Step 3: Remove quotation marks
    sanitized_name := REGEXP_REPLACE(sanitized_name, '[''"`´]', '', 'g');
    
    -- Step 4: Remove other special characters
    sanitized_name := REGEXP_REPLACE(sanitized_name, '[^\w\s\-\.]', '', 'g');
    
    -- Step 5: Normalize spaces
    sanitized_name := REGEXP_REPLACE(sanitized_name, '\s+', ' ', 'g');
    
    -- Step 6: Trim whitespace
    sanitized_name := TRIM(sanitized_name);
    
    RETURN sanitized_name;
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN LOWER(TRIM(input_name));
END;
$$ LANGUAGE plpgsql IMMUTABLE
SET client_encoding = 'UTF8';
*/

-- =====================================================================================
-- Test cases for the sanitize_plant_name function
-- =====================================================================================


-- =====================================================================================
-- Performance optimization: Create index on sanitized names
-- =====================================================================================

-- This would typically be run after creating the function to improve search performance
-- CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_facit_sanitized_name 
-- ON facit (sanitize_plant_name(name));

-- CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_facit_sanitized_sv_name 
-- ON facit (sanitize_plant_name(sv_name)) 
-- WHERE sv_name IS NOT NULL;
