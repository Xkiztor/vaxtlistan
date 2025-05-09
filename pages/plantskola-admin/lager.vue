<script setup lang="ts">
definePageMeta({
  layout: 'admin',
  middleware: 'plantskola-admin',
});
// --- Types ---
import type { Totallager, Facit, Plantskola } from '~/types/supabase-tables';

// --- State ---
const user = useSupabaseUser();
const supabase = useSupabaseClient();
const router = useRouter();

// Search/filter state
const search = ref('');
const filterType = ref('');
const types = [
  { value: 'T', label: 'Träd' },
  { value: 'P', label: 'Perenner' },
  { value: 'K', label: 'Klätterväxter' },
  { value: 'O', label: 'Ormbunke' },
  { value: 'B', label: 'Barrträd' },
];

const showAddModal = ref(false);
const showEditModal = ref(false);
const editPlant = ref<(Totallager & { facit: Facit }) | null>(null);

// --- Fetch plantskola id ---
const { data: plantskola } = await useAsyncData('plantskola', async () => {
  if (!user.value) return null;
  const { data, error } = await supabase
    .from('plantskolor')
    .select('id, name')
    .eq('user_id', user.value.id)
    .single();
  if (error || !data) return null;
  return data as Plantskola;
});

// --- Fetch lager with facit relation ---
const {
  data: lager,
  refresh: refreshLager,
  status: lagerStatus,
} = await useAsyncData('lager', async () => {
  if (!plantskola.value) return [];
  const { data, error } = await supabase
    .from('totallager')
    .select('*, facit:facit_id(id, name, sv_name, type)')
    .eq('plantskola_id', plantskola.value.id)
    .order('created_at', { ascending: false });
  if (error || !data) return [];
  return data as Array<Totallager & { facit: Facit }>;
});

// --- Fetch all facit for add/edit ---
const { data: allFacit } = await useAsyncData('allFacit', async () => {
  const { data, error } = await supabase.from('facit').select();
  if (error || !data) return [];
  return data as Facit[];
});

// --- Computed filtered list ---
const filteredLager = computed(() => {
  if (!lager.value) return [];
  // let result;
  // if (updatedPlant.value !== null) result = updatedPlant.value;
  // else result = lager.value;
  let result = lager.value;
  if (search.value) {
    const s = search.value.toLowerCase();
    result = result.filter(
      (p) =>
        p.name_by_plantskola?.toLowerCase().includes(s) ||
        p.facit?.sv_name?.toLowerCase().includes(s) ||
        p.facit?.name?.toLowerCase().includes(s)
    );
  }
  if (filterType.value) {
    result = result.filter((p) => p.facit?.type === filterType.value);
  }
  return result;
});

// --- Unique types for filter ---

// --- Method to update plant ---
const onPlantUpdate = ({ id, field, value }: { id: number; field: string; value: any }) => {
  if (!lager.value) return;
  const idx = lager.value.findIndex((p) => p.id === id);
  if (idx !== -1) {
    // Use Vue reactivity: update the field and last_edited directly on the reactive object
    lager.value[idx][field] = value;
    lager.value[idx].last_edited = new Date().toISOString();
  }
};
</script>

<template>
  <div class="max-w-4xl mx-auto py-10 px-4">
    <div class="flex flex-col md:flex-row md:items-end md:justify-between gap-4 mb-8">
      <div>
        <h1 class="text-3xl md:text-4xl font-black">Lager</h1>
        <div class="text-muted text-lg">Alla växter för {{ plantskola?.name || 'plantskola' }}</div>
      </div>
    </div>
    <!-- Search and filter -->
    <div class="flex flex-col md:flex-row gap-4 mb-4">
      <UInput
        v-model="search"
        placeholder="Sök på namn eller art..."
        size="xl"
        class="flex-1"
        icon="i-heroicons-magnifying-glass"
      />
      <div class="flex flex-row items-center gap-2">
        <USelect
          v-model="filterType"
          :items="types"
          placeholder="Filtrera på typ"
          size="xl"
          class="w-full md:w-60 transition-all"
          :ui="{ item: 'cursor-pointer' }"
        />

        <UButton
          v-if="filterType"
          variant="outline"
          class="w-10"
          @click="filterType = ''"
          icon="material-symbols:close-rounded"
          size="xl"
        />
      </div>
    </div>
    <!-- Lager list -->
    <div v-if="lagerStatus === 'pending'" class="flex justify-center py-12">
      <!-- <ULoader size="lg" color="primary" /> -->
      Laddar...
    </div>
    <div v-else-if="filteredLager.length > 0" class="flex flex-col gap-4">
      <LagerListItem
        v-for="plant in filteredLager"
        :key="plant.id"
        :plant="plant"
        :facit="allFacit"
        @update="onPlantUpdate"
      />
    </div>
    <div v-else class="text-muted italic py-8 text-center">Inga växter hittades.</div>
  </div>
</template>

<style>
.appear-enter-active,
.appear-leave-active {
  transition: all 0.8s ease;
}
.appear-enter-from,
.appear-leave-to {
  width: 0;
  /* opacity: 0; */
}
</style>
