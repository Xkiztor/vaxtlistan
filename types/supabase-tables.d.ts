// Types for Supabase tables based on AI-instructions.md

// Field mappings as constants for array fields in the Facit table
export const SUNLIGHT = {
  NO_PREFERENCE: 0,
  FULL_SUN: 1,
  PARTIAL_SHADE: 2,
  FULL_SHADE: 3
} as const;

export const SOIL_TYPE = {
  NO_PREFERENCE: 0,
  LOAM: 1,
  CHALK: 2,
  SAND: 3,
  CLAY: 4
} as const;

export const FULL_HEIGHT_TIME = {
  NO_PREFERENCE: 0,
  ONE_YEAR: 1,
  ONE_TO_TWO_YEARS: 2,
  TWO_TO_FIVE_YEARS: 3,
  FIVE_TO_TEN_YEARS: 4,
  TEN_TO_TWENTY_YEARS: 5,
  TWENTY_TO_FIFTY_YEARS: 6,
  MORE_THAN_FIFTY_YEARS: 7
} as const;

export const MOISTURE = {
  NO_PREFERENCE: 0,
  WELL_DRAINED: 1,
  POORLY_DRAINED: 2,
  MOIST_BUT_WELL_DRAINED: 3
} as const;

export const PH = {
  NO_PREFERENCE: 0,
  ACID: 1,
  ALKALINE: 2,
  NEUTRAL: 3
} as const;

export const EXPOSURE = {
  NO_PREFERENCE: 0,
  SHELTERED: 1,
  EXPOSED: 2
} as const;

export const SEASON_OF_INTEREST = {
  SPRING: 1,
  SUMMER: 2,
  AUTUMN: 3,
  WINTER: 4
} as const;

export const COLORS = {
  BLACK: 1,
  BLUE: 2,
  BRONZE: 3,
  BROWN: 4,
  CREAM: 5,
  GREEN: 6,
  GREY: 7,
  ORANGE: 8,
  PINK: 9,
  PURPLE: 10,
  RED: 11,
  SILVER: 12,
  VARIEGATED: 13,
  WHITE: 14,
  YELLOW: 15,
  GOLD: 16
} as const;

// Also provide reverse mappings for display purposes
export const SUNLIGHT_LABELS = {
  [SUNLIGHT.NO_PREFERENCE]: "---",
  [SUNLIGHT.FULL_SUN]: "Soligt",
  [SUNLIGHT.PARTIAL_SHADE]: "Delvis skuggigt",
  [SUNLIGHT.FULL_SHADE]: "Helt skuggigt"
} as const;

export const SOIL_TYPE_LABELS = {
  [SOIL_TYPE.NO_PREFERENCE]: "---",
  [SOIL_TYPE.LOAM]: "Matjord",
  [SOIL_TYPE.CHALK]: "Kalk",
  [SOIL_TYPE.SAND]: "Sand",
  [SOIL_TYPE.CLAY]: "Lera"
} as const;

export const FULL_HEIGHT_TIME_LABELS = {
  [FULL_HEIGHT_TIME.NO_PREFERENCE]: "---",
  [FULL_HEIGHT_TIME.ONE_YEAR]: "1 år",
  [FULL_HEIGHT_TIME.ONE_TO_TWO_YEARS]: "1–2 år",
  [FULL_HEIGHT_TIME.TWO_TO_FIVE_YEARS]: "2–5 år",
  [FULL_HEIGHT_TIME.FIVE_TO_TEN_YEARS]: "5–10 år",
  [FULL_HEIGHT_TIME.TEN_TO_TWENTY_YEARS]: "10–20 år",
  [FULL_HEIGHT_TIME.TWENTY_TO_FIFTY_YEARS]: "20–50 år",
  [FULL_HEIGHT_TIME.MORE_THAN_FIFTY_YEARS]: "Mer än 50 år"
} as const;

export const MOISTURE_LABELS = {
  [MOISTURE.NO_PREFERENCE]: "---",
  [MOISTURE.WELL_DRAINED]: "Väldränerad",
  [MOISTURE.POORLY_DRAINED]: "Odränerat",
  [MOISTURE.MOIST_BUT_WELL_DRAINED]: "Fuktigt men dränerat"
} as const;

export const PH_LABELS = {
  [PH.NO_PREFERENCE]: "---",
  [PH.ACID]: "Surt",
  [PH.ALKALINE]: "Basiskt",
  [PH.NEUTRAL]: "Neutralt"
} as const;

export const EXPOSURE_LABELS = {
  [EXPOSURE.NO_PREFERENCE]: "---",
  [EXPOSURE.SHELTERED]: "Skyddad",
  [EXPOSURE.EXPOSED]: "Oskyddad"
} as const;

export const SEASON_OF_INTEREST_LABELS = {
  [SEASON_OF_INTEREST.SPRING]: "Vår",
  [SEASON_OF_INTEREST.SUMMER]: "Sommar",
  [SEASON_OF_INTEREST.AUTUMN]: "Höst",
  [SEASON_OF_INTEREST.WINTER]: "Vinter"
} as const;

export const COLORS_LABELS = {
  [COLORS.BLACK]: "Svart",
  [COLORS.BLUE]: "Blå",
  [COLORS.BRONZE]: "Brons",
  [COLORS.BROWN]: "Brun",
  [COLORS.CREAM]: "Krämfärgad",
  [COLORS.GREEN]: "Grön",
  [COLORS.GREY]: "Grå",
  [COLORS.ORANGE]: "Orange",
  [COLORS.PINK]: "Rosa",
  [COLORS.PURPLE]: "Lila",
  [COLORS.RED]: "Röd",
  [COLORS.SILVER]: "Silver",
  [COLORS.VARIEGATED]: "Brokig",
  [COLORS.WHITE]: "Vit",
  [COLORS.YELLOW]: "Gul",
  [COLORS.GOLD]: "Guld"
} as const;

export const RHS_TYPES = {
  PERENNIAL: 1,
  CLIMBER_WALL_SHRUB: 2,
  BEDDING: 3,
  BULBS: 4,
  FERNS: 5,
  SHRUBS: 6,
  ALPINE_ROCKERY: 8,
  ROSES: 9,
  GRASS_LIKE: 10,
  CONSERVATORY_GREENHOUSE: 11,
  FRUIT_EDIBLE: 12,
  TREES: 13,
  BAMBOOS: 17,
  BOGS: 18,
  CONIFERS: 19
} as const;

export const RHS_TYPES_LABELS = {
  [RHS_TYPES.PERENNIAL]: "Perenn",
  [RHS_TYPES.CLIMBER_WALL_SHRUB]: "Klätterväxt",
  [RHS_TYPES.BEDDING]: "Utplanteringsväxt",
  [RHS_TYPES.BULBS]: "Lökväxt",
  [RHS_TYPES.FERNS]: "Ormbunke",
  [RHS_TYPES.SHRUBS]: "Buske",
  [RHS_TYPES.ALPINE_ROCKERY]: "Alpinväxt",
  [RHS_TYPES.ROSES]: "Ros",
  [RHS_TYPES.GRASS_LIKE]: "Gräsliknande",
  [RHS_TYPES.CONSERVATORY_GREENHOUSE]: "Växthusväxt",
  [RHS_TYPES.FRUIT_EDIBLE]: "Ätbar växt",
  [RHS_TYPES.TREES]: "Träd",
  [RHS_TYPES.BAMBOOS]: "Bambu",
  [RHS_TYPES.BOGS]: "Kärrväxt",
  [RHS_TYPES.CONIFERS]: "Barrträd"
} as const;

// Table: facit
export interface Facit {
  id: number; // bigint (auto-generated). Unique identifier for the plant.
  created_at: string; // timestamp with time zone (ISO string). When the record was created.
  name: string; // text. Scientific name (e.g. "Pinus cembra 'Stricta'").
  sv_name?: string | null; // text. Native/common name (e.g. "Arolla pine 'Stricta'").
  is_recommended?: boolean | null; // boolean. Whether this is a recommended name.
  is_original?: boolean | null; // boolean. Whether this is the original name.
  is_synonym?: boolean | null; // boolean. Whether this is a synonym.
  synonym_to?: string | null; // text. If synonym, the accepted name it refers to.
  synonym_to_id?: number | null; // bigint. FK to facit.id - the ID of the accepted plant name.
  has_synonyms?: string | null; // text. Seperated by " | ". The plant names that refer to this plant.  
  has_synonyms_id?: string | null; // text. Seperated by " | ". The plant ids that refer to this plant.
  taxonomy_type?: string | null; // text. Type of taxonomy (e.g. "species", "cultivar").
  plant_type?: string | null; // text. Plant type/category (e.g. "T" for trees).
  grupp?: string | null; // text. The grupp of the plant (e.g. "Therian-Gruppen").
  serie?: string | null; // text. The serie of the plant.
  spread?: string | null; // text. Typical spread (e.g. "2.5-4 meter").
  height?: string | null; // text. Typical height (e.g. "8-12 meter").
  rhs_id?: number | null; // bigint. RHS database ID.
  sunlight?: number[] | null; // ARRAY of smallint. Sunlight preferences.
  soil_type?: number[] | null; // ARRAY of smallint. Soil type preferences.
  full_height_time?: number[] | null; // ARRAY of smallint. Time to full height.
  moisture?: number[] | null; // ARRAY of smallint. Moisture preferences.
  ph?: number[] | null; // ARRAY of smallint. Soil pH preferences.
  exposure?: number[] | null; // ARRAY of smallint. Exposure preferences.
  season_of_interest?: number[] | null; // ARRAY of smallint. Seasons of interest.
  colors?: string[] | null; // ARRAY of text. Color attributes in compressed format.
  rhs_types?: number[] | null; // ARRAY of smallint. RHS plant types. Sub-category of plant_type.
  user_submitted?: boolean | null; // boolean. Whether the entry was user-submitted.
  created_by?: number | null; // bigint. User or nursery who created the entry.
  last_edited?: string | null; // timestamp with time zone (ISO string). When last edited.
}

// Table: plantskolor
export interface Plantskola {
  id: number; // Int8
  name: string; // Text
  adress: string; // Text
  email: string; // Text
  phone: string; // Text
  url: string; // Text
  postorder: boolean; // Bool
  on_site: boolean; // Bool
  verified: boolean; // Bool
  hidden: boolean; // Bool
  description: string; // Text
  user_id: string; // UUID
  created_at: string; // Timestampz (ISO string)
  last_edited: string; // Timestampz (ISO string)
}

// Table: totallager
export interface Totallager {
  id: number; // Int8
  facit_id: number; // Int8 (FK facit, linked)
  plantskola_id: number; // Int8 (FK plantskolor, linked)
  name_by_plantskola: string; // Text
  comment_by_plantskola: string; // Text
  private_comment_by_plantskola: string; // Text
  id_by_plantskola: string; // Text - Custom ID/code assigned by plantskola
  pot: string; // Text
  height: string; // Text
  price: number; // Numeric
  hidden: boolean; // Bool
  stock: number; // Int8
  own_columns: Record<string, any> | null; // JSONB - Custom fields added by plantskola
  created_at: string; // Timestampz (ISO string)
  last_edited: string; // Timestampz (ISO string)
}

// Table: superadmins
export interface Superadmin {
  id: number; // Int8
  user_id: string; // UUID
}

// Function return type for get_plantskola_lager_complete() in lager-fetch.sql
export interface LagerComplete {
  // Totallager fields
  id: number;
  facit_id: number;
  plantskola_id: number;
  name_by_plantskola?: string | null;
  comment_by_plantskola?: string | null;
  private_comment_by_plantskola?: string | null;
  id_by_plantskola?: string | null;
  pot?: string | null;
  height?: string | null;
  price?: number | null;
  stock?: number | null;
  hidden?: boolean | null;
  own_columns?: Record<string, any> | null;
  created_at?: string | null;
  last_edited?: string | null;
  
  // Facit fields (enriched data with facit_ prefix) - must match SQL function exactly
  facit_name?: string | null;
  facit_sv_name?: string | null;
  facit_plant_type?: string | null;
  facit_grupp?: string | null;
  facit_serie?: string | null;
  facit_rhs_types?: number[] | null;
  facit_taxonomy_type?: string | null;
  facit_is_synonym?: boolean | null;
  facit_synonym_to?: string | null;
  facit_synonym_to_id?: number | null;
  facit_has_synonyms?: string | null;
  facit_has_synonyms_id?: string | null;
  facit_spread?: number[] | null; // SMALLINT[]
  facit_height?: number[] | null; // SMALLINT[]
  facit_sunlight?: number[] | null;
  facit_colors?: string[] | null;
  facit_season_of_interest?: number[] | null;
  facit_user_submitted?: boolean | null;
  facit_created_by?: number | null;  facit_created_at?: string | null;
}

// Search function return types for ALL plants (used by PlantPicker)
export interface PlantSearchResult {
  id: number;
  name: string;
  sv_name?: string | null;
  plant_type?: string | null;
  grupp?: string | null;
  serie?: string | null;
  rhs_types?: number[] | null;
  is_synonym?: boolean | null;
  synonym_to?: string | null;
  synonym_to_id?: number | null;
  spread?: string | null;
  height?: string | null;
  colors?: string[] | null;
  last_edited?: string | null;
}

export interface PlantSimilaritySearchResult extends PlantSearchResult {
  similarity_score: number;
}

// Search function return types for AVAILABLE plants (used by search page and inline search)
export interface AvailablePlantSearchResult {
  id: number;
  name: string;
  sv_name?: string | null;
  plant_type?: string | null;
  rhs_types?: number[] | null;
  taxonomy_type?: string | null;
  is_synonym?: boolean | null;
  synonym_to?: string | null;
  synonym_to_id?: number | null;
  spread?: string | null;
  height?: string | null;
  colors?: string[] | null;
  last_edited?: string | null;
  available_count: number; // Total stock across all plantskolor
  plantskolor_count: number; // Number of plantskolor that have this plant
  prices: PriceInfo[]; // Detailed price information with nursery details
  min_price?: number; // Cheapest available price
  max_price?: number; // Most expensive available price
  avg_price?: number; // Average price across nurseries
  nursery_info?: NurseryInfo; // Aggregated nursery information
  plant_attributes?: PlantAttributes; // Detailed plant characteristics
  total_results?: number; // Total matching results (for pagination)
}

export interface PriceInfo {
  price: number;
  stock?: number | null;
  pot?: string | null;
  height?: string | null;
  nursery_id: number;
  nursery_name: string;
  postorder: boolean;
  on_site: boolean;
  nursery_address?: string | null;
}

export interface NurseryInfo {
  postorder_available: boolean;
  on_site_available: boolean;
  verified_nurseries: number;
  total_nurseries: number;
  nursery_names: string[];
}

export interface PlantAttributes {
  height?: string | null;
  spread?: string | null;
  sunlight?: number[] | null;
  colors?: string[] | null;
  season_interest?: number[] | null;
}

export interface AvailablePlantSimilaritySearchResult extends AvailablePlantSearchResult {
  similarity_score: number;
}

// Import workflow types for strict and fuzzy search
export interface StrictMatchResult {
  id: number;
  name: string;
  sv_name: string | null;
  similarity_score: number;
  is_exact_match: boolean;
  match_type: string; // 'name' or 'sv_name'
}

export interface FuzzyMatchResult {
  id: number;
  name: string;
  sv_name: string | null;
  similarity_score: number;
  match_details: string; // JSON string with match information
  suggested_reason: string; // Why this plant is suggested
}

// RPC function types for fuzzy search
export interface Database {
  public: {
    Tables: {
      // Existing table types...
    }
    Functions: {
      search_plants_fuzzy_match: {
        Args: {
          p_search_term: string
          p_result_limit?: number
          p_minimum_similarity?: number
        }
        Returns: {
          id: number
          name: string
          sv_name?: string
          plant_type?: string
          has_synonyms?: string
          has_synonyms_id?: string
          user_submitted?: boolean
          created_by?: number
          similarity_score: number
          match_details?: string
          suggested_reason?: string
        }[]
      }
      search_plants_fuzzy_match_batch: {
        Args: {
          p_search_terms: string[]
          p_result_limit?: number
          p_minimum_similarity?: number
        }
        Returns: {
          search_term: string
          id: number
          name: string
          sv_name?: string
          plant_type?: string
          has_synonyms?: string
          has_synonyms_id?: string
          user_submitted?: boolean
          created_by?: number
          similarity_score: number
          match_details?: string
          suggested_reason?: string
        }[]
      }
    }
  }
}

// Enhanced search result interface for the new search_all_plants function
export interface EnhancedPlantSearchResult extends Facit {
  similarity_score: number; // Float (0.0-1.0). Similarity score from trigram matching
  matched_synonym: string | null; // Text. Which synonym was matched (if any)
}