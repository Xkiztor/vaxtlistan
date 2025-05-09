<script setup lang="ts">
import type { Plantskola, Totallager, Facit } from '~/types/supabase-tables';

// Get current user and supabase client
const user = useSupabaseUser();
const supabase = useSupabaseClient();
const router = useRouter();

// Fetch plantskola info for greeting
const { data: plantskola } = await useAsyncData('plantskola', async () => {
  if (!user.value) return null;
  const { data, error } = await supabase
    .from('plantskolor')
    .select()
    .eq('user_id', user.value.id)
    .single();
  if (error || !data) return null;
  return data as Plantskola;
});

// Fetch a preview of plants in lager (limit 5)
const { data: lagerPreview, status: lagerStatus } = await useAsyncData('lagerPreview', async () => {
  if (!user.value) return [];
  // Get plantskola id
  const { data: pk, error: pkError } = await supabase
    .from('plantskolor')
    .select('id')
    .eq('user_id', user.value.id)
    .single();
  if (pkError || !pk) return [];
  // Get up to 5 plants from totallager for this plantskola
  const { data, error } = await supabase
    .from('totallager')
    .select('*')
    .eq('plantskola_id', pk.id)
    .order('created_at', { ascending: false })
    .limit(5);
  if (error || !data) return [];
  return data as Totallager[];
});

const { data: allFacit } = await useAsyncData('allFacit', async () => {
  const { data, error } = await supabase.from('facit').select();
  if (error || !data) return [];
  return data as Facit[];
});

// Handler for 'Visa alla' button
const goToLager = () => {
  router.push('/plantskola-admin/lager');
};

definePageMeta({
  layout: 'admin',
  middleware: 'plantskola-admin',
});
</script>

<template>
  <div class="max-w-2xl mx-auto py-10 px-4">
    <!-- Greeting -->
    <h1 class="text-3xl md:text-4xl font-bold mb-6 flex items-center gap-2">
      Hej <span class="italic underline font-black">{{ plantskola?.name || 'plantskola' }}</span>
      <UIcon
        name="material-symbols:verified-rounded"
        class="text-secondary"
        v-if="plantskola!.verified"
      />
    </h1>
    <!-- Lager preview -->
    <div class="mb-8">
      <h2 class="text-xl font-bold mb-2">Senaste växterna</h2>
      <div v-if="lagerStatus === 'pending'" class="flex justify-center py-8">Laddar växter...</div>
      <ul v-else-if="lagerPreview && lagerPreview.length > 0" class="flex flex-col gap-4">
        <li
          v-for="plant in lagerPreview"
          :key="plant.id"
          class="flex flex-col sm:flex-row items-center gap-4 p-2 rounded-lg bg-elevated border-1 border-regular"
        >
          <div class="flex-1">
            <div>
              <span class="font-bold text-lg">{{
                allFacit?.find((item) => item.id === plant.facit_id)!.name
              }}</span>
              <span v-if="plant.name_by_plantskola"> ({{ plant.name_by_plantskola }})</span>
            </div>
            <div class="flex flex-wrap gap-2 mt-1">
              <UBadge color="neutral" variant="subtle" v-if="plant.pot"
                >Kruka: {{ plant.pot }}</UBadge
              >
              <UBadge color="neutral" variant="subtle" v-if="plant.height"
                >Höjd: {{ plant.height }}</UBadge
              >
            </div>
          </div>
          <div class="flex flex-col gap-2 items-end">
            <UBadge color="neutral" size="xl" variant="subtle" v-if="plant.price"
              ><span class="font-black">{{ plant.price }} kr</span></UBadge
            >
            <UBadge color="neutral" variant="subtle" v-if="plant.stock > 0"
              >Lager: <span class="font-black">{{ plant.stock }} st</span></UBadge
            >
            <UBadge color="error" variant="soft" v-else>Slut i lager</UBadge>
          </div>
        </li>
      </ul>
      <div v-else class="text-muted italic py-4">Du har inga växter i lager ännu.</div>
      <UButton class="mt-6 w-full md:w-auto" color="primary" size="xl" @click="goToLager">
        Visa alla
      </UButton>
    </div>
  </div>
</template>

<style scoped>
/* Only use Nuxt UI and Tailwind classes */
</style>
