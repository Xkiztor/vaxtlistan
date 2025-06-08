<script setup lang="ts">
// PlantPicker.vue - reusable plant selection component for edit/create
// Uses Nuxt UI, SSR-friendly, emits selected plant id
import type { Facit } from '~/types/supabase-tables';
import { useVirtualList } from '@vueuse/core';
import Fuse from 'fuse.js'; // Import Fuse.js

// Supabase client
const supabase = useSupabaseClient();

const props = defineProps<{
  editValue: number; // Selected plant id
  currentPlantID: number; // ID of the current plant
}>();

// Search input
const search = ref('');
const minSearchLength = 3; // Minimum length for search to trigger

// Use facit store for SSR-friendly plant data
const facitStore = useFacitStore();
const loading = computed(() => facitStore.loading.value);
const error = computed(() => facitStore.error.value);

await useAsyncData('allFacit', () => facitStore.fetchFacit(supabase));

// Fuse.js options for strict search
const fuseOptions = {
  keys: [
    { name: 'name', weight: 0.7 },
    { name: 'sv_name', weight: 0.3 },
  ],
  threshold: 0.3, // strict matching
  ignoreLocation: true,
  minMatchCharLength: minSearchLength,
  // Normalize and strip diacritics/special characters for both search and data
  getFn: (obj: Facit, path: string) => {
    const value = (obj as any)[path];
    if (typeof value !== 'string') return value;
    // Normalize to NFD and remove diacritics and special characters
    return value
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '') // Remove diacritics
      .replace(/[^a-zA-Z0-9\s]/g, '') // Remove special characters
      .toLowerCase();
  },
};
let fuse: Fuse<Facit> | null = null;

// Watch facit and update Fuse instance
watch(
  () => facitStore.facit,
  (facit) => {
    if (facit) {
      fuse = new Fuse(facit, fuseOptions);
    }
  },
  { immediate: true }
);

// Filtered list based on search using Fuse.js
const filteredPlants = computed(() => {
  if (!facitStore.facit) return [];
  // If search is empty or too short, show only the selected plant (editValue) if it exists
  if (!search.value || search.value.length < minSearchLength) {
    const selected = facitStore.facit.find((p) => p.id === props.currentPlantID);
    return selected ? [selected] : [];
  }
  if (!fuse) return [];
  // Use Fuse for strict fuzzy search
  return fuse.search(search.value).map((result) => result.item);
});

// Virtual list setup for filteredPlants (VueUse docs style)
const { list, containerProps, wrapperProps } = useVirtualList(filteredPlants, {
  itemHeight: 73,
});

// Add plant
const types = [
  { value: 'T', label: 'Träd' },
  { value: 'B', label: 'Barrträd' },
  { value: 'P', label: 'Perenn' },
  { value: 'K', label: 'Klätterväxt' },
  { value: 'O', label: 'Ormbunke' },
];

const modalOpen = ref(false);
const closeAdd = () => {
  modalOpen.value = false;
  addInputName.value = '';
  addInputSv.value = '';
  addInputZon.value = null;
  addInputType.value = '';
  addInputEdible.value = false;
};

const addInputName = ref('');
const addInputSv = ref('');
const addInputZon = ref(null);
const addInputType = ref('');
const addInputEdible = ref(false);

// Add plant to facit table via store
const addPlant = async () => {
  if (addInputZon.value === 0) {
    addInputZon.value = null;
  }
  // Validate required fields
  if (!addInputName.value.trim() || !addInputType.value) {
    useToast().add({
      title: 'Fel',
      description: 'Artnamn och typ är obligatoriska.',
      color: 'error',
    });
    return;
  }
  // Fetch plantskola id for created_by
  const user = useSupabaseUser();
  const { data: pk, error: pkError } = await supabase
    .from('plantskolor')
    .select('id')
    .eq('user_id', user.value.id)
    .single();
  if (pkError || !pk) {
    useToast().add({
      title: 'Fel',
      description: 'Kunde inte hitta plantskola-id.',
      color: 'error',
    });
    return;
  }
  // Prepare insert data
  const newPlant = {
    name: addInputName.value.trim(),
    sv_name: addInputSv.value.trim() || null,
    type: addInputType.value,
    edible: addInputEdible.value,
    zone: addInputZon.value ? Number(addInputZon.value) : null,
    user_submitted: true,
    created_at: new Date().toISOString(),
    last_edited: new Date().toISOString(),
    created_by: pk.id,
  };
  // Add via facit store
  const added = await facitStore.addFacit(supabase, newPlant);
  if (!added) {
    useToast().add({
      title: 'Fel vid uppladdning',
      description: facitStore.error.value || 'Kunde inte lägga till växt.',
      color: 'error',
    });
    return;
  }
  // Select the newly added plant by id
  addSelectPlant(added.id);
  useToast().add({
    title: 'Växt tillagd',
    color: 'primary',
  });
  closeAdd();
};

// Emit selected plant id
const emit = defineEmits(['select', 'addSelect']);
const selectPlant = (id: number) => {
  emit('select', id);
};
const addSelectPlant = (id: number) => {
  emit('addSelect', id);
};
</script>

<template>
  <div class="flex flex-col gap-4">
    <!-- Search input -->
    <UInput
      v-model="search"
      placeholder="Sök växtnamn..."
      icon="i-heroicons-magnifying-glass"
      size="xl"
      class="w-full"
      :disabled="loading"
    />

    <!-- Loading state -->
    <div v-if="loading" class="flex justify-center py-8">
      <USkeleton class="h-10 w-full rounded-lg" />
    </div>

    <!-- Virtual plant list -->
    <div v-else class="border border-border rounded-lg bg-bg-elevated h-72 md:h-96">
      <div v-bind="containerProps" class="overflow-scroll h-full" v-if="filteredPlants.length > 0">
        <div v-bind="wrapperProps">
          <div
            v-for="item in list"
            :key="item.data.id"
            class="cursor-pointer hover:bg-bg-accented transition px-4 py-3 flex gap-1 border-b border-border last:border-b-0 items-center"
            @click="selectPlant(item.data.id)"
          >
            <span
              class="grow"
              :class="{
                'text-t-muted': item.data.id === currentPlantID,
                'text-primary': item.data.id === editValue,
              }"
            >
              <span class="font-semibold max-md:block mr-1">{{ item.data.name }}</span>
              <span v-if="item.data.sv_name" class="text-t-muted text-sm">{{
                item.data.sv_name
              }}</span>
            </span>
            <UButton
              size="sm"
              class="shrink-0 h-min"
              :disabled="item.data.id === currentPlantID || item.data.id === editValue"
            >
              Välj</UButton
            >
          </div>
        </div>
      </div>
      <div
        v-else-if="search.length > minSearchLength"
        class="text-t-muted italic px-4 py-3 absolute w-full"
      >
        Inga växter hittades.
      </div>
    </div>
    <div>
      <span class="text-t-toned text-sm">Finns inte växten?</span>
      <UModal v-model:open="modalOpen" @close="closeAdd" :close="{ onClick: closeAdd }">
        <UButton class="w-full" variant="outline" icon="material-symbols:add"> Ny växt </UButton>
        <template #content>
          <div class="flex flex-col gap-4 p-4">
            <div class="flex flex-col gap-2">
              <UFormField
                label="Artnamn - latin"
                description="Se till att vara väldigt noga med stavningen"
                required
              >
                <UInput v-model="addInputName" size="xl" class="w-full" />
              </UFormField>
              <UFormField label="Svenskt namn">
                <UInput v-model="addInputSv" size="md" class="w-full" />
              </UFormField>
              <UFormField label="Zon">
                <UInputNumber v-model="addInputZon" size="md" class="w-full" />
              </UFormField>
              <UFormField label="Typ" required>
                <USelect
                  v-model="addInputType"
                  :items="types"
                  class="w-full"
                  :ui="{ item: 'cursor-pointer' }"
                />
                <!-- <UInput v-model="addInputType" placeholder="Typ" size="md" class="w-full" /> -->
              </UFormField>
              <UFormField label="Ätbar?" required>
                <USwitch v-model="addInputEdible" size="md" class="w-full" />
                <!-- <UInput v-model="addInputEdible" placeholder="Ätbar?" size="md" class="w-full" /> -->
              </UFormField>
            </div>
            <div class="flex gap-2 justify-end">
              <UButton class="" @click="closeAdd" color="neutral" variant="ghost">Avbryt</UButton>
              <UButton class="" @click="addPlant" icon="material-symbols:add" :loading="loading">
                Lägg till</UButton
              >
            </div>
          </div>
        </template>
      </UModal>
    </div>
  </div>
</template>

<style scoped>
/* No custom CSS. Use Tailwind and Nuxt UI classes only. */
</style>
