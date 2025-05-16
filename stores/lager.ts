import { defineStore } from 'pinia';
import { ref } from 'vue';
import type { Totallager } from '~/types/supabase-tables';

export const useLagerStore = defineStore('lager', () => {
  // Global state for lager data
  const lager = ref<Totallager[] | null>(null);
  const loading = ref(false);
  const error = ref<string | null>(null);

  // Fetch lager for a plantskola
  const fetchLager = async (supabase: any, plantskolaId: number) => {
    loading.value = true;
    error.value = null;
    try {
      const { data, error: fetchError } = await supabase
        .from('totallager')
        .select('*')
        .eq('plantskola_id', plantskolaId)
        .order('created_at', { ascending: false });
      if (fetchError) throw fetchError;
      lager.value = data as Totallager[];
      return lager.value;
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
      if (lager.value) {
        lager.value = [data as Totallager, ...lager.value];
      } else {
        lager.value = [data as Totallager];
      }
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
      if (lager.value) {
        const idx = lager.value.findIndex((p) => p.id === id);
        if (idx !== -1) {
          lager.value[idx] = { ...lager.value[idx], ...updateObj };
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
    if (lager.value) {
      lager.value = lager.value.filter((p) => p.id !== id);
    }
  };

  // Update hidden state for a plant in lager (local state only)
  const setPlantHiddenState = (id: number, hidden: boolean) => {
    if (lager.value) {
      const idx = lager.value.findIndex((p) => p.id === id);
      if (idx !== -1) {
        lager.value[idx] = { ...lager.value[idx], hidden };
      }
    }
  };

  // Refresh lager
  const refreshLager = async (supabase: any, plantskolaId: number) => {
    lager.value = null;
    return await fetchLager(supabase, plantskolaId);
  };

  return { lager, loading, error, fetchLager, addPlantToLager, updateLagerField, refreshLager, removePlantFromLager, setPlantHiddenState };
});
