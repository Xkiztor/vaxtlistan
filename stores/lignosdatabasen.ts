import { defineStore } from 'pinia';
import { ref } from 'vue';
import { createClient } from '@supabase/supabase-js';
// import { useRuntimeConfig } from '#app';

export const useLignosdatabasen = defineStore('lignosdatabasen', () => {

  // const runtimeConfig = useRuntimeConfig();
  // const supabase = createClient('https://oykwqfkocubjvrixrunf.supabase.co', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95a3dxZmtvY3VianZyaXhydW5mIiwicm9sZSI6ImFub24iLCJpYXQiOjE2NjMzNjMxMjUsImV4cCI6MTk3ODkzOTEyNX0.fthY1hbpesNps0RFKQxVA8Z10PLWD-3M_LJmkubhVF4');
  
  // Global state for other table data
  // const otherTable = ref<OtherTable[] | null>(null); // Uncomment and adjust type
  const lignosdatabasen = ref<any[] | null>(null); // Use any[] if you don't have a type yet
  const loading = ref(false);
  const error = ref<string | null>(null);
  
  // Fetch data from the other table only if not already loaded
  async function getLignosdatabasen(runtimeConfig) {

    const supabase = createClient(runtimeConfig.public.LINDERSPLANTSKOLA_SUPABASE_URL, runtimeConfig.public.LINDERSPLANTSKOLA_SUPABASE_KEY);

    if (lignosdatabasen.value) return lignosdatabasen.value;
    loading.value = true;
    error.value = null;
    try {
      const { data, error: fetchError } = await supabase.from('lignosdatabasen').select('*');
      if (fetchError) throw fetchError;
      lignosdatabasen.value = data; // Add type assertion if you have a type
      return lignosdatabasen.value;
    } catch (e: any) {
      error.value = e.message || 'Kunde inte hämta data.';
      return null;
    } finally {
      loading.value = false;
    }
  }


  return { lignosdatabasen, loading, error, getLignosdatabasen };
});
