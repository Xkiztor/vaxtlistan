// composables/usePlantType.ts
import { computed } from 'vue';
import { RHS_TYPES_LABELS } from '~/types/supabase-tables.d.ts';

// Map RHS type numbers to Swedish labels
const rhsTypeMap: Record<number, string> = {
  1: 'Perenn',
  2: 'Klätterväxt',
  3: 'Utplanteringsväxt',
  4: 'Lökväxt',
  5: 'Ormbunke',
  6: 'Buske',
  8: 'Alpinväxt',
  9: 'Ros',
  10: 'Gräsliknande',
  11: 'Växthusväxt',
  12: 'Ätbar växt',
  13: 'Träd',
  17: 'Bambu',
  18: 'Kärrväxt',
  19: 'Barrträd',
};

// Legacy type map for backwards compatibility
const legacyTypeMap: Record<string, string> = {
  T: 'Träd',
  B: 'Barrträd',
  G: 'Gräs',
  O: 'Ormbunke',
  K: 'Klätterväxt',
  P: 'Perenn',
};

const reverseLegacyTypeMap = Object.fromEntries(
  Object.entries(legacyTypeMap).map(([k, v]) => [v, k])
);

export function usePlantType() {
  // Get primary RHS type label for a plant
  function getRhsTypeLabel(rhsTypes: number[] | null | undefined): string {
    if (!rhsTypes || rhsTypes.length === 0) return '';
    return rhsTypeMap[rhsTypes[0]] || '';
  }

  // Get all RHS type labels for a plant
  function getAllRhsTypeLabels(rhsTypes: number[] | null | undefined): string[] {
    if (!rhsTypes || rhsTypes.length === 0) return [];
    return rhsTypes.map(type => rhsTypeMap[type]).filter(Boolean);
  }

  // Legacy functions for backwards compatibility
  function letterToType(letter: string): string {
    return legacyTypeMap[letter] || '';
  }
  
  function typeToLetter(type: string): string {
    return reverseLegacyTypeMap[type] || '';
  }

  return { 
    getRhsTypeLabel, 
    getAllRhsTypeLabels,
    letterToType, 
    typeToLetter 
  };
}
