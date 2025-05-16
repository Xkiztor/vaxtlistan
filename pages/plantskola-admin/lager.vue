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

// --- Stores ---
import { useLagerStore } from '~/stores/lager';
import { useFacitStore } from '~/stores/facit';

const lagerStore = useLagerStore();
const facitStore = useFacitStore();

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

// --- Fetch lager from store ---
await useAsyncData('lager', async () => {
  if (!plantskola.value) return [];
  return await lagerStore.fetchLager(supabase, plantskola.value.id);
});

// --- Fetch facit from store ---
await useAsyncData('allFacit', () => facitStore.fetchFacit(supabase));

// --- Computed filtered list ---
const filteredLager = computed(() => {
  if (!lagerStore.lager) return [];
  let result = lagerStore.lager;
  if (search.value) {
    const s = search.value.toLowerCase();
    result = result.filter(
      (p) =>
        p.name_by_plantskola?.toLowerCase().includes(s) ||
        facitStore.getFacitById(p.facit_id)?.sv_name?.toLowerCase().includes(s) ||
        facitStore.getFacitById(p.facit_id)?.name?.toLowerCase().includes(s)
    );
  }
  if (filterType.value) {
    result = result.filter((p) => facitStore.getFacitById(p.facit_id)?.type === filterType.value);
  }
  return result;
});

// --- Add new plant to lager ---
const addPlantModalOpen = ref(false);
const newPlantFacitId = ref<number | null>(null);
const addPlantLoading = ref(false);

const onPlantPickerSelect = (facitId: number) => {
  newPlantFacitId.value = facitId;
};

const addPlantToLager = async () => {
  if (!plantskola.value || !newPlantFacitId.value) return;
  addPlantLoading.value = true;
  await lagerStore.addPlantToLager(supabase, {
    facit_id: newPlantFacitId.value,
    plantskola_id: plantskola.value.id,
    created_at: new Date().toISOString(),
    last_edited: new Date().toISOString(),
    stock: 0,
    price: 0,
    hidden: false,
  });
  addPlantLoading.value = false;
  addPlantModalOpen.value = false;
  newPlantFacitId.value = null;
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
    <div v-if="lagerStore.status === 'pending'" class="flex justify-center py-12">
      <!-- <ULoader size="lg" color="primary" /> -->
      Laddar...
    </div>
    <div v-else-if="filteredLager.length > 0" class="flex flex-col gap-4">
      <LagerListItem
        v-for="plant in filteredLager"
        :key="plant.id"
        :plant="plant"
        :facit="facitStore.facit"
        @update="lagerStore.updatePlant"
      />
    </div>
    <div v-else class="text-muted italic py-8 text-center">Inga växter hittades.</div>
    <!-- Add plant modal -->
    <UModal v-model="addPlantModalOpen" title="Lägg till växt">
      <template #content>
        <PlantPicker @select="onPlantPickerSelect" />
      </template>
      <template #footer>
        <UButton :loading="addPlantLoading" @click="addPlantToLager" variant="primary" size="lg">
          Lägg till
        </UButton>
      </template>
    </UModal>
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
