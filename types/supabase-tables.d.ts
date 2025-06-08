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

// Table: facit
export interface Facit {
  id: number; // bigint. Unique identifier for the plant taxon.
  created_at: string; // timestamp with time zone (ISO string). When the record was created.
  name: string; // text. Scientific name (e.g. "Pinus cembra 'Stricta'").
  sv_name: string; // text. Native/common name (e.g. "Arolla pine 'Stricta'").
  full_json: any; // jsonb. Full JSON object with all plant data (see example in AI-instructions.md).
  is_recommended: boolean; // boolean. Whether this is a recommended name.
  is_original: boolean; // boolean. Whether this is the original name.
  is_synonym: boolean; // boolean. Whether this is a synonym.
  synonym_to: string; // text. If synonym, the accepted name it refers to.
  taxonomy_type: string; // text. Type of taxonomy (e.g. "species", "cultivar").
  plant_type: string; // text. Plant type/category (e.g. "T").
  rhs_hardiness: number; // bigint. RHS hardiness level (see AI-instructions.md for mapping).
  spread: string; // text. Typical spread (e.g. "2.5-4 metres").
  height: string; // text. Typical height (e.g. "8-12 metres").
  rhs_id: number; // bigint. RHS database ID.
  sunlight: number[]; // ARRAY of smallint. Sunlight preferences (see AI-instructions.md for mapping).
  soil_type: number[]; // ARRAY of smallint. Soil type preferences (see AI-instructions.md for mapping).
  full_height_time: number[]; // ARRAY of smallint. Time to full height (see AI-instructions.md for mapping).
  moisture: number[]; // ARRAY of smallint. Moisture preferences (see AI-instructions.md for mapping).
  ph: number[]; // ARRAY of smallint. Soil pH preferences (see AI-instructions.md for mapping).
  exposure: number[]; // ARRAY of smallint. Exposure preferences (see AI-instructions.md for mapping).
  season_of_interest: number[]; // ARRAY of smallint. Seasons of interest (see AI-instructions.md for mapping).
  colors: string[]; // ARRAY of string  Color attributes (see AI-instructions.md for mapping).
  rhs_types: number[]; // ARRAY of smallint. RHS types (see AI-instructions.md for mapping).
  user_submitted: boolean; // boolean. Whether the entry was user-submitted.
  created_by: number; // bigint. User or nursery who created the entry.
  last_edited: string; // timestamp with time zone (ISO string). When the record was last edited.
}

// Table: plantskolor
export interface Plantskola {
  id: number; // Int8
  name: string; // Text
  adress: string; // Text
  email: string; // Text
  phone: string; // Text
  verified: boolean; // Bool
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
  description_by_plantskola: string; // Text
  pot: string; // Text
  height: string; // Text
  price: number; // Numeric
  hidden: boolean; // Bool
  stock: number; // Int8
  created_at: string; // Timestampz (ISO string)
  last_edited: string; // Timestampz (ISO string)
}

// Table: superadmins
export interface Superadmin {
  id: number; // Int8
  user_id: string; // UUID
}