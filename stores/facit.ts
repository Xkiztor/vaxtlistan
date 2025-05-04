import { defineStore } from 'pinia';
import { ref } from 'vue';
import type { Facit, FacitFuse } from '~/types/supabase-tables';

export const useFacitStore = defineStore('facit', () => {

  // Global state for facit data
  const facit = ref<Facit[] | null>(null);
  const loading = ref(false);
  const error = ref<string | null>(null);

  // Fetch facit from Supabase only if not already loaded
  async function fetchFacit(supabase: any) {
    if (facit.value) return facit.value;
    loading.value = true;
    error.value = null;
    try {
      const { data, error: fetchError } = await supabase.from('facit').select('*');
      if (fetchError) throw fetchError;
      facit.value = data as Facit[];
      return facit.value;
    } catch (e: any) {
      error.value = e.message || 'Kunde inte hämta facit.';
      return null;
    } finally {
      loading.value = false;
    }
  }

  // Optionally, a method to force refresh
  async function refreshFacit(supabase: any) {
    facit.value = null;
    return await fetchFacit(supabase);
  }

  return { facit, loading, error, fetchFacit, refreshFacit };
});
