import { defineStore } from 'pinia';
import { ref, reactive } from 'vue';
import type { Facit } from '~/types/supabase-tables';

export const useFacitStore = defineStore('facit', () => {
  // Global state for facit data
  const facit = ref<Facit[] | null>(null);
  const loading = ref(false);
  const error = ref<string | null>(null);

  // Add new facit (plant) to Supabase and local state
  const addFacit = async (supabase: any, newPlant: Partial<Facit>) => {
    loading.value = true;
    error.value = null;
    try {
      const { data, error: addError } = await supabase
        .from('facit')
        .insert([newPlant])
        .select('*')
        .single();
      if (addError) throw addError;
      if (facit.value) {
        facit.value.push(reactive(data as Facit));
        // facit.value = [...facit.value, reactive(data as Facit)];
      } else {
        facit.value = [reactive(data as Facit)];
      }
      return data as Facit;
    } catch (e: any) {
      error.value = e.message || 'Kunde inte lägga till växt.';
      return null;
    } finally {
      loading.value = false;
    }
  };

  // Update a facit item (for future editing support)
  const updateFacit = async (supabase: any, id: number, updateObj: Partial<Facit>) => {
    loading.value = true;
    error.value = null;
    try {
      const { data, error: upError } = await supabase
        .from('facit')
        .update(updateObj)
        .eq('id', id)
        .select('*')
        .single();
      if (upError) throw upError;
      if (facit.value) {
        const idx = facit.value.findIndex((f) => f.id === id);
        if (idx !== -1) {
          facit.value[idx] = { ...facit.value[idx], ...updateObj } as Facit;
        }
      }
      return data as Facit;
    } catch (e: any) {
      error.value = e.message || 'Kunde inte uppdatera växt.';
      return null;
    } finally {
      loading.value = false;
    }
  };

  // Get facit by id
  const getFacitById = (id: number): Facit | undefined => {
    return facit.value?.find(f => f.id === id);
  };

  return { facit, loading, error, addFacit, updateFacit, getFacitById };
});
