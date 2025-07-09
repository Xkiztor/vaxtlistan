<script setup lang="ts">
// PlantPicker.vue - reusable plant selection component for edit/create
// Uses enhanced search with fuzzy matching, similarity scoring, and synonym detection
import type { EnhancedPlantSearchResult } from '~/types/supabase-tables';
import { useVirtualList } from '@vueuse/core';

// Supabase client
const supabase = useSupabaseClient();
const { searchAllPlants } = useSearch();

const props = defineProps<{
  editValue: number; // Selected plant id
  currentPlantID: number; // ID of the current plant
}>();

// Search input and state
const search = ref('');
const minSearchLength = 2; // Minimum length for search to trigger
const searchResults = ref<EnhancedPlantSearchResult[]>([]);
const loading = ref(false);
const hasSearched = ref(false);
const canSearch = computed(() => search.value.length >= minSearchLength);
const searchTime = ref(0); // Track search performance

// Enhanced search options - using fixed threshold
const minimumSimilarity = 0.25; // Fixed similarity threshold

// Get current plant data if available
const { data: currentPlant } = await useAsyncData(
  `currentPlant-${props.currentPlantID}`,
  async () => {
    if (!props.currentPlantID) return null;
    const { data, error } = await supabase
      .from('facit')
      .select('*')
      .eq('id', props.currentPlantID)
      .single();

    if (error) {
      console.error('Error fetching current plant:', error);
      return null;
    }
    return data;
  },
  { server: false }
);

const limit = 100;
// Perform search using optimized search function
const performSearch = async () => {
  if (!search.value || search.value.length < minSearchLength) {
    searchResults.value = [];
    hasSearched.value = false;
    return;
  }

  loading.value = true;
  hasSearched.value = true;
  try {
    const result = await searchAllPlants(search.value, {
      limit: limit, // Limit results for picker
      minimumSimilarity: minimumSimilarity, // Use fixed similarity threshold
    });

    searchResults.value = result.results;
    searchTime.value = result.searchTime;
  } catch (error) {
    console.error('Search error:', error);
    searchResults.value = [];
    useToast().add({
      title: 'Sökfel',
      description: 'Kunde inte utföra sökning. Försök igen.',
      color: 'error',
    });
  } finally {
    loading.value = false;
  }
};

// Handle manual search trigger (button click or Enter key)
const triggerSearch = () => {
  if (canSearch.value) {
    performSearch();
  }
};

// Handle Enter key press
const handleKeyPress = (event: KeyboardEvent) => {
  if (event.key === 'Enter') {
    triggerSearch();
  }
};

// Remove automatic search watching - now manual only
// watch(search, () => {
//   if (search.value.length >= minSearchLength) {
//     debouncedSearch();
//   } else {
//     searchResults.value = [];
//     hasSearched.value = false;
//   }
// });

// Clear results when search is too short
watch(search, () => {
  if (search.value.length < minSearchLength) {
    searchResults.value = [];
    hasSearched.value = false;
  }
});

// Plants to display in list
const plantsToDisplay = computed(() => {
  // If we have search results, show them
  if (hasSearched.value && searchResults.value.length > 0) {
    return searchResults.value;
  }

  // If no search or search is too short, show current plant if available
  if ((!search.value || search.value.length < minSearchLength) && currentPlant.value) {
    return [currentPlant.value];
  }

  return [];
});

// Add plant
const rhs_types_options = [
  { value: 13, label: 'Träd' },
  { value: 19, label: 'Barrträd' },
  { value: 1, label: 'Perenn' },
  { value: 2, label: 'Klätterväxt' },
  { value: 5, label: 'Ormbunke' },
  { value: 6, label: 'Buske' },
  { value: 9, label: 'Ros' },
  { value: 12, label: 'Ätbar växt' },
];

const modalOpen = ref(false);
const closeAdd = () => {
  modalOpen.value = false;
  addInputName.value = '';
  addInputSv.value = '';
  addInputRhsType.value = undefined;
};

const addInputName = ref('');
const addInputSv = ref('');
const addInputRhsType = ref<number | undefined>(undefined);

// Add plant to facit table
const addPlant = async () => {
  // Validate required fields
  if (!addInputName.value.trim() || !addInputRhsType.value) {
    useToast().add({
      title: 'Fel',
      description: 'Artnamn och typ är obligatoriska.',
      color: 'error',
    });
    return;
  }

  // Get plantskola id for created_by
  const user = useSupabaseUser();
  if (!user.value) {
    useToast().add({
      title: 'Fel',
      description: 'Du måste vara inloggad.',
      color: 'error',
    });
    return;
  }

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

  // Prepare insert data according to new facit structure
  const newPlant = {
    name: addInputName.value.trim(),
    sv_name: addInputSv.value.trim() || null,
    rhs_types: addInputRhsType.value ? [addInputRhsType.value] : null,
    user_submitted: true,
    created_by: (pk as any).id,
  };
  try {
    // Insert directly via Supabase instead of using store
    const { data: added, error: addError } = await supabase
      .from('facit')
      .insert(newPlant as any)
      .select()
      .single();

    if (addError || !added) {
      console.error('Error adding plant:', addError);
      useToast().add({
        title: 'Fel vid uppladdning',
        description: 'Kunde inte lägga till växt.',
        color: 'error',
      });
      return;
    }

    // Select the newly added plant by id
    addSelectPlant((added as any).id);
    useToast().add({
      title: 'Växt tillagd',
      color: 'primary',
    });
    closeAdd();
  } catch (error) {
    console.error('Error adding plant:', error);
    useToast().add({
      title: 'Fel vid uppladdning',
      description: 'Kunde inte lägga till växt.',
      color: 'error',
    });
  }
};

// Emit selected plant id and data
const emit = defineEmits(['select', 'addSelect']);
const selectPlant = (id: number) => {
  // Find the plant data to include with the selection
  const selectedPlant = plantsToDisplay.value.find((plant) => plant.id === id);
  emit('select', id, selectedPlant);
};
const addSelectPlant = (id: number) => {
  // For newly added plants, we could fetch the data, but for now just emit the ID
  // The parent component will handle this case appropriately
  emit('addSelect', id, null);
};
</script>

<template>
  <div class="flex flex-col gap-4">
    <!-- Search input with button -->
    <div class="flex gap-2">
      <UInput
        v-model="search"
        placeholder="Sök växtnamn..."
        icon="i-heroicons-magnifying-glass"
        size="xl"
        class="flex-1"
        :disabled="loading"
        @keypress="handleKeyPress"
      />
      <UButton
        size="xl"
        color="primary"
        icon="i-heroicons-magnifying-glass"
        :disabled="!canSearch || loading"
        :loading="loading"
        loading-icon="ant-design:loading-outlined"
        @click="triggerSearch"
      >
        Sök
      </UButton>
    </div>

    <!-- Loading state with nice spinner -->
    <div
      v-if="loading"
      class="border border-border rounded-lg bg-bg-elevated h-72 md:h-96 flex items-center justify-center"
    >
      <div class="flex flex-col items-center gap-4">
        <div class="relative">
          <div class="w-12 h-12 border-4 border-border rounded-full"></div>
          <div
            class="absolute top-0 left-0 w-12 h-12 border-4 border-primary border-t-transparent rounded-full animate-spin"
          ></div>
        </div>
        <span class="text-t-muted text-sm">Söker växter...</span>
      </div>
    </div>

    <div v-else class="border border-border rounded-lg bg-bg-elevated h-72 md:h-96">
      <div class="overflow-auto h-full" v-if="plantsToDisplay.length > 0">
        <div
          v-for="item in plantsToDisplay"
          :key="item.id"
          class="cursor-pointer hover:bg-bg-accented transition px-4 py-3 flex gap-3 border-b border-border last:border-b-0"
          @click="selectPlant(item.id)"
        >
          <div class="grow flex flex-col justify-center">
            <!-- Main plant name and swedish name -->
            <div
              class="grow block leading-tight"
              :class="{
                'text-t-muted': item.id === currentPlantID,
                'text-primary': item.id === editValue,
              }"
            >
              <span class="font-semibold max-md:block mr-2">{{ item.name }}</span>
              <span v-if="item.sv_name" class="text-t-muted text-sm">{{ item.sv_name }}</span>
            </div>
            <!-- Enhanced search information -->
            <div class="mt-1 text-xs text-t-muted" v-if="item.matched_synonym">
              <!-- Matched synonym indicator - only show if synonym was actually matched -->
              Matchad via synonym: <span class="font-medium">{{ item.matched_synonym }}</span>
            </div>
          </div>

          <!-- Selection button with improved positioning -->
          <UButton
            size="sm"
            class="shrink-0 max-h-max my-auto"
            :disabled="item.id === currentPlantID"
          >
            Välj
          </UButton>
        </div>
        <div class="py-6" v-if="plantsToDisplay.length >= limit">
          <p class="text-t-muted text-sm text-center">
            Visar endast de första {{ limit }} resultaten. Försök med mer specifik sökning.
          </p>
        </div>
        <!-- Search performance info -->
        <div
          v-if="hasSearched && searchTime > 0 && searchResults.length < 100"
          class="py-2 px-4 bg-bg-elevated"
        >
          <p class="text-t-muted text-xs text-center">
            {{ searchResults.length }} resultat hittades
          </p>
        </div>
      </div>
      <div
        v-else-if="hasSearched && search.length >= minSearchLength"
        class="text-t-muted italic px-4 py-3 flex items-center justify-center h-full"
      >
        <div class="text-center">
          <UIcon name="i-heroicons-magnifying-glass" class="w-8 h-8 mx-auto mb-2 text-t-toned" />
          <div>Inga växter hittades för "{{ search }}".</div>
          <div class="text-sm mt-1">Försök med andra sökord eller lägg till en ny växt.</div>
        </div>
      </div>
      <div
        v-else-if="!hasSearched && search.length >= minSearchLength"
        class="text-t-muted italic px-4 py-3 flex items-center justify-center h-full"
      >
        <div class="text-center">
          <UIcon name="i-heroicons-magnifying-glass" class="w-8 h-8 mx-auto mb-2 text-t-toned" />
          <div>Tryck på "Sök" eller Enter för att söka</div>
        </div>
      </div>
      <div v-else class="text-t-muted italic px-4 py-3 flex items-center justify-center h-full">
        <div class="text-center">
          <UIcon name="i-heroicons-magnifying-glass" class="w-8 h-8 mx-auto mb-2 text-t-toned" />
          <div>
            {{
              currentPlant
                ? 'Nuvarande växt visas ovan'
                : 'Sök efter växter genom att skriva i sökfältet'
            }}.
          </div>
        </div>
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
              <UFormField label="Typ" required>
                <USelect
                  v-model="addInputRhsType"
                  :options="rhs_types_options"
                  class="w-full"
                  :ui="{ item: 'cursor-pointer' }"
                />
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
