// Types for Supabase tables based on AI-instructions.md

// Table: facit
export interface Facit {
  id: number; // Int8
  name: string; // Text
  sv_name: string; // Text
  type: string; // Text
  edible: boolean; // Bool
  zone: number; // Int8
  max_height: number; // Int8
  max_width: number; // Int8
  created_at: string; // Timestampz (ISO string)
  last_edited: string; // Timestampz (ISO string)
}

// Table: facit (for Fuse.js search)
export interface FacitFuse {
  item: {
    id: number; // Int8
    name: string; // Text
    sv_name: string; // Text
    type: string; // Text
    edible: boolean; // Bool
    zone: number; // Int8
    max_height: number; // Int8
    max_width: number; // Int8
  },
  matches: Array,
  refIndex: number,
  score: number,
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
