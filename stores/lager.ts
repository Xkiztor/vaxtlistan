import { defineStore } from 'pinia';
import { ref } from 'vue';
import type { Totallager, LagerComplete } from '~/types/supabase-tables';

export const useLagerStore = defineStore('lager', () => {
  // Global state for complete lager data with facit information
  const lagerComplete = ref<LagerComplete[] | null>(null);
  const loading = ref(false);
  const error = ref<string | null>(null);
  // Fetch complete lager data using the SQL function
  const fetchLagerComplete = async (supabase: any, plantskolaId: number) => {
    loading.value = true;
    error.value = null;
    try {
      const { data, error: fetchError } = await supabase.rpc('get_plantskola_lager_complete', {
        p_plantskola_id: plantskolaId
      } as any); // Type assertion to handle Supabase RPC parameter typing
      if (fetchError) throw fetchError;
      lagerComplete.value = data as LagerComplete[];
      return lagerComplete.value;
    } catch (e: any) {
      error.value = e.message || 'Kunde inte hämta lager.';
      return null;
    } finally {
      loading.value = false;
    }
  };
  // Add a new plant to lager
  const addPlantToLager = async (supabase: any, plant: Partial<Totallager>) => {
    loading.value = true;
    error.value = null;
    try {
      const { data, error: addError } = await supabase
        .from('totallager')
        .insert([plant])
        .select('*')
        .single();
      if (addError) throw addError;
      return data as Totallager;
    } catch (e: any) {
      error.value = e.message || 'Kunde inte lägga till växt.';
      return null;
    } finally {
      loading.value = false;
    }
  };

  // Update a field for a plant in lager
  const updateLagerField = async (
    supabase: any,
    id: number,
    field: keyof Totallager,
    value: any
  ) => {
    loading.value = true;
    error.value = null;
    try {
      const updateObj: any = { [field]: value, last_edited: new Date().toISOString() };
      const { error: upError } = await supabase
        .from('totallager')
        .update(updateObj)
        .eq('id', id);
      if (upError) throw upError;
      // Update local state
      if (lagerComplete.value) {
        const idx = lagerComplete.value.findIndex((p) => p.id === id);
        if (idx !== -1) {
          lagerComplete.value[idx] = { ...lagerComplete.value[idx], ...updateObj };
        }
      }
      return true;
    } catch (e: any) {
      error.value = e.message || 'Kunde inte uppdatera växt.';
      return false;
    } finally {
      loading.value = false;
    }
  };

  // Remove a plant from lager (local state only)
  const removePlantFromLager = (id: number) => {
    if (lagerComplete.value) {
      lagerComplete.value = lagerComplete.value.filter((p) => p.id !== id);
    }
  };

  // Update hidden state for a plant in lager (local state only)
  const setPlantHiddenState = (id: number, hidden: boolean) => {
    if (lagerComplete.value) {
      const idx = lagerComplete.value.findIndex((p) => p.id === id);
      if (idx !== -1) {
        lagerComplete.value[idx] = { ...lagerComplete.value[idx], hidden };
      }
    }
  };

  // Refresh lager
  const refreshLager = async (supabase: any, plantskolaId: number) => {
    lagerComplete.value = null;
    return await fetchLagerComplete(supabase, plantskolaId);
  };

  return { 
    lagerComplete, 
    loading, 
    error, 
    fetchLagerComplete, 
    addPlantToLager, 
    updateLagerField, 
    refreshLager, 
    removePlantFromLager, 
    setPlantHiddenState 
  };
});
