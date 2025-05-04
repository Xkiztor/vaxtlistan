<script setup lang="ts">
import type { FacitFuse } from '~/types/supabase-tables';
import Fuse from 'fuse.js'; // Import Fuse.js for fuzzy search
import { useFacitStore } from '~/stores/facit';

const supabase = useSupabaseClient();
const runtimeConfig = useRuntimeConfig();

const route = useRoute();
const router = useRouter();

const facitStore = useFacitStore();

const lignosdatabasen = useLignosdatabasen(); // Import lignosdatabasen if needed
const { data: lignosdatabasenData } = await useAsyncData('lignosdatabasen', () =>
  lignosdatabasen.getLignosdatabasen(runtimeConfig)
);

// Search input, initialized from query param if present
const search = ref(route.query.q || '');
// Filtered and sorted plant results
const filteredPlants = ref<FacitFuse[]>([]);
const hasSearched = ref(false);
// Loading and error states
const loading = ref(true);
const errorMsg = ref('');

// Fetch all plants using Pinia store (only fetches if not already loaded)
async function fetchAllPlants() {
  loading.value = true;
  errorMsg.value = '';
  try {
    await facitStore.fetchFacit(supabase);
  } catch (e) {
    errorMsg.value = 'Kunde inte hämta växtdata.';
  } finally {
    loading.value = false;
  }
}

// Perform fuzzy search using Fuse.js
function performSearch() {
  hasSearched.value = true;
  // Update query param for SEO and navigation
  router.replace({ query: { ...route.query, q: search.value || undefined } });
  if (!search.value) {
    filteredPlants.value = [];
    return;
  }
  // Use Fuse.js for smart, fuzzy search
  const fuse = new Fuse(facitStore.facit || [], {
    keys: ['name', 'sv_name'],
    threshold: 0.4, // Adjust for strictness
    includeScore: true,
    ignoreLocation: true,
    includeMatches: true,
  });
  const results = fuse.search(search.value);
  filteredPlants.value = results
    .map((item) => {
      if (item.matches && item.matches[0]?.key === 'sv_name' && typeof item.score === 'number') {
        return { ...item, score: item.score * 10 };
      }
      return item;
    })
    .sort((a, b) => (a.score ?? 0) - (b.score ?? 0));
  // filteredPlants.value = results.length > 6 ? results.filter((item) => item.score! < 0.5) : results;
}

// --- Lifecycle: fetch and search on mount, and watch for query changes ---
onMounted(async () => {
  await fetchAllPlants();
  if (search.value) performSearch();
});

// Watch for changes in the route query (e.g., browser navigation)
watch(
  () => route.query.q,
  (newQ) => {
    if (typeof newQ === 'string') {
      search.value = newQ;
      performSearch();
    }
  }
);

// Trigger search on button click or Enter
function onSearch() {
  performSearch();
}
</script>

<template>
  <!-- Main container -->
  <UContainer class="py-8">
    <!-- Search input -->
    <div class="flex flex-col sm:flex-row items-center gap-4 mb-8">
      <UInput
        v-model="search"
        placeholder="Sök växtnamn..."
        size="xl"
        class="w-full sm:w-96"
        @keyup.enter="onSearch"
        @blur="performSearch"
        @submit.prevent="onSearch"
        icon="i-material-symbols-search-rounded"
        rounded
      />
      <UButton color="primary" size="xl" @click="onSearch" rounded>Sök</UButton>
    </div>

    <!-- Loading state -->
    <div v-if="loading" class="flex justify-center items-center py-16">
      <ULoader size="lg" color="primary" />
    </div>

    <!-- Error state -->
    <div v-if="errorMsg" color="error" variant="soft" class="mb-4">
      {{ errorMsg }}
    </div>

    <!-- No results -->
    <div v-if="!loading && filteredPlants && filteredPlants.length === 0 && search && hasSearched">
      <div color="info" variant="soft">Inga växter hittades för "{{ search }}".</div>
    </div>

    <!-- Results list -->
    <div
      v-if="filteredPlants && filteredPlants.length > 0"
      class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6"
    >
      <SearchResultCard v-for="plant in filteredPlants" :key="plant.item.id" :plant="plant" />
    </div>
  </UContainer>
</template>

<style scoped>
/* No custom colors, use Tailwind or Nuxt UI classes only */
</style>
