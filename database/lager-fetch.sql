-- Function to fetch complete lager information for a plantskola
-- This function joins totallager with facit to provide enriched plant data
-- Usage: SELECT * FROM get_plantskola_lager_complete(plantskola_id);

CREATE OR REPLACE FUNCTION get_plantskola_lager_complete(p_plantskola_id bigint)
RETURNS TABLE (
  -- Totallager fields
  id bigint,
  facit_id bigint,
  plantskola_id bigint,
  name_by_plantskola text,
  comment_by_plantskola text,
  pot text,
  height text,
  price numeric,
  hidden boolean,
  stock bigint,
  created_at timestamptz,
  last_edited timestamptz,
  
  -- Facit fields (enriched data)
  facit_name text,
  facit_sv_name text,
  facit_is_recommended boolean,
  facit_is_original boolean,
  facit_is_synonym boolean,
  facit_synonym_to text,
  facit_taxonomy_type text,
  facit_plant_type text,
  facit_rhs_types smallint[],
  facit_rhs_hardiness bigint,
  facit_spread text,
  facit_height text,
  facit_rhs_id bigint,
  facit_sunlight smallint[],
  facit_soil_type smallint[],
  facit_full_height_time smallint[],
  facit_moisture smallint[],
  facit_ph smallint[],
  facit_exposure smallint[],
  facit_season_of_interest smallint[],
  facit_colors text[],
  facit_user_submitted boolean,
  facit_created_by bigint,
  facit_created_at timestamptz,
  facit_last_edited timestamptz
)
LANGUAGE sql
STABLE
AS $$
  SELECT 
    -- Totallager fields
    t.id,
    t.facit_id,
    t.plantskola_id,
    t.name_by_plantskola,
    t.comment_by_plantskola,
    t.pot,
    t.height,
    t.price,
    t.hidden,
    t.stock,
    t.created_at,
    t.last_edited,
    
    -- Facit fields (prefixed with facit_ to avoid naming conflicts)
    f.name as facit_name,
    f.sv_name as facit_sv_name,
    f.is_recommended as facit_is_recommended,
    f.is_original as facit_is_original,
    f.is_synonym as facit_is_synonym,
    f.synonym_to as facit_synonym_to,
    f.taxonomy_type as facit_taxonomy_type,
    f.plant_type as facit_plant_type,
    f.rhs_types as facit_rhs_types,
    f.rhs_hardiness as facit_rhs_hardiness,
    f.spread as facit_spread,
    f.height as facit_height,
    f.rhs_id as facit_rhs_id,
    f.sunlight as facit_sunlight,
    f.soil_type as facit_soil_type,
    f.full_height_time as facit_full_height_time,
    f.moisture as facit_moisture,
    f.ph as facit_ph,
    f.exposure as facit_exposure,
    f.season_of_interest as facit_season_of_interest,
    f.colors as facit_colors,
    f.user_submitted as facit_user_submitted,
    f.created_by as facit_created_by,
    f.created_at as facit_created_at,
    f.last_edited as facit_last_edited
  FROM totallager t
  LEFT JOIN facit f ON t.facit_id = f.id
  WHERE t.plantskola_id = p_plantskola_id
  ORDER BY f.name DESC;
$$;
