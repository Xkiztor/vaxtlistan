// composables/usePlantType.ts
import { computed } from 'vue';

const typeMap: Record<string, string> = {
  T: 'Träd',
  B: 'Barrträd',
  G: 'Gräs',
  O: 'Ormbunke',
  K: 'Klätterväxt',
  P: 'Perenn',
};

const reverseTypeMap = Object.fromEntries(
  Object.entries(typeMap).map(([k, v]) => [v, k])
);

export function usePlantType() {
  function letterToType(letter: string): string {
    return typeMap[letter] || '';
  }
  function typeToLetter(type: string): string {
    return reverseTypeMap[type] || '';
  }
  return { letterToType, typeToLetter };
}
