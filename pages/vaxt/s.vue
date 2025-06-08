<script setup lang="ts">
import type { Facit } from '~/types/supabase-tables';

const supabase = useSupabaseClient();
const route = useRoute();
const router = useRouter();
const { searchPlants } = useSearch();

// Search input, initialized from query param if present
const search = ref(typeof route.query.q === 'string' ? route.query.q : '');
// Filtered plant results from search query
const searchResults = ref<Facit[]>([]);
const hasSearched = ref(false);
// Loading and error states
const loading = ref(false);
const errorMsg = ref('');
const searchTime = ref(0);
const totalResults = ref(0);

// Pagination - initialize from URL params
const currentPage = ref(typeof route.query.sida === 'string' ? parseInt(route.query.sida) || 1 : 1);
const itemsPerPage = 60;
const totalPages = computed(() => Math.ceil(totalResults.value / itemsPerPage));

// Minimum character threshold for search
const MIN_SEARCH_LENGTH = 2;

/**
 * High-performance server-side search functionality
 * Only triggers on explicit user action (Enter key or button click)
 */
async function performSearch(immediate = false) {
  if (!search.value || search.value.length < MIN_SEARCH_LENGTH) {
    searchResults.value = [];
    hasSearched.value = false;
    totalResults.value = 0;
    return;
  }

  loading.value = true;
  errorMsg.value = '';

  // Update URL for deep linking without page reload - include both search query and page
  const query: Record<string, string | undefined> = {
    ...route.query,
    q: search.value || undefined,
    sida: currentPage.value > 1 ? currentPage.value.toString() : undefined,
  };

  router.replace({ query });

  try {
    const offset = (currentPage.value - 1) * itemsPerPage;

    // Use the new ultra-fast optimized search function
    const result = await searchPlants(search.value, {
      limit: itemsPerPage,
      offset,
      includeCount: currentPage.value === 1, // Only get count on first page
    });

    searchResults.value = result.results;
    searchTime.value = result.searchTime;

    if (currentPage.value === 1) {
      totalResults.value = result.totalCount;
    }

    hasSearched.value = true;
  } catch (error) {
    console.error('Search error:', error);
    errorMsg.value = 'Ett fel uppstod vid sökning. Försök igen.';
    searchResults.value = [];
    totalResults.value = 0;
  } finally {
    loading.value = false;
  }
}

// Trigger search on button click or Enter key
function onSearch() {
  currentPage.value = 1; // Reset to first page
  performSearch(true);
}

// Handle pagination
function goToPage(page: number) {
  currentPage.value = page;
  performSearch(true);
  // Scroll to top of results
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

// Load search results on mount if URL contains search parameters
onMounted(async () => {
  // This handles initial loading when navigating directly to a search URL
  if (search.value && search.value.length >= MIN_SEARCH_LENGTH) {
    performSearch(true);
  }
});

// Watch for changes in the route query (e.g., browser navigation)
watch(
  () => route.query,
  (newQuery) => {
    const newQ = newQuery.q;
    const newPage = newQuery.sida;

    // Handle search query changes
    if (typeof newQ === 'string' && newQ !== search.value) {
      search.value = newQ;
    }

    // Handle page changes
    const pageNum = typeof newPage === 'string' ? parseInt(newPage) || 1 : 1;
    if (pageNum !== currentPage.value) {
      currentPage.value = pageNum;
    }

    // Perform search if we have a query and it's from URL navigation
    if (search.value && search.value.length >= MIN_SEARCH_LENGTH) {
      performSearch(true);
    }
  },
  { deep: true }
);

// Clear results when search input is completely cleared
watch(search, (newValue) => {
  if (newValue.length === 0) {
    searchResults.value = [];
    hasSearched.value = false;
    totalResults.value = 0;
    // Clear URL query parameters when search is cleared
    router.replace({ query: {} });
  }
});

// Set page metadata for SEO
useHead({
  title: search.value ? `Sök växter: ${search.value} | Växtlistan` : 'Sök växter | Växtlistan',
  meta: [
    {
      name: 'description',
      content: search.value
        ? `Sök efter ${search.value} och andra växter i Växtlistan - hitta tillgängliga växter i svenska plantskolor.`
        : 'Sök efter växter i Växtlistan - hitta tillgängliga växter i svenska plantskolor.',
    },
  ],
});

const testVar = ref(1234567); // Example variable for testing purposes
</script>

<template>
  <!-- Main container -->
  <div class="p-4 sm:p-8 max-w-7xl mx-auto">
    <!-- Search input -->
    <div class="flex flex-col sm:flex-row items-stretch sm:items-center gap-4 mb-4">
      <div class="relative w-full sm:w-96 flex-grow">
        <UInput
          v-model="search"
          placeholder="Sök växtnamn..."
          size="xl"
          class="w-full"
          leading-icon="i-material-symbols-search-rounded"
          @keydown.enter="onSearch"
          :ui="{
            leadingIcon: 'pointer-events-none',
            leading: 'pointer-events-none',
          }"
          autocomplete="off"
        >
          <template #trailing>
            <UButton
              v-if="search.length > 0"
              color="neutral"
              variant="ghost"
              size="xs"
              icon="i-material-symbols-close-rounded"
              @click="search = ''"
              class="!p-1"
              aria-label="Rensa sökfält"
            />
          </template>
        </UInput>
      </div>
      <UButton
        @click="onSearch"
        size="xl"
        icon="i-material-symbols-search-rounded"
        loading-icon="ant-design:loading-outlined"
        :loading="loading"
        :disabled="search.length < MIN_SEARCH_LENGTH || loading"
      >
        Sök
      </UButton>
    </div>

    <!-- Search results info -->
    <div v-if="hasSearched && !loading" class="mb-6">
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2">
        <p class="text-t-muted">
          <span v-if="totalResults > 0"> {{ totalResults.toLocaleString('sv-SE') }} resultat </span>
          <span v-else> Inga resultat </span>
        </p>
        <p v-if="searchTime > 0" class="text-sm text-t-muted">
          Sökning tog {{ Math.round(searchTime) }}ms
        </p>
      </div>
    </div>

    <!-- Error message -->
    <div v-if="errorMsg" class="mb-6">
      <div class="bg-red-50 border border-red-200 text-red-800 px-4 py-3 rounded-lg">
        {{ errorMsg }}
      </div>
    </div>

    <!-- Loading state -->
    <div v-if="loading" class="flex justify-center py-12">
      <div class="flex items-center flex-col gap-3 text-t-muted">
        <UIcon name="ant-design:loading-outlined" class="animate-spin" size="40" />
        <span>Söker...</span>
      </div>
    </div>

    <!-- Search results -->
    <div v-else-if="hasSearched">
      <div v-if="searchResults.length > 0" class="space-y-4">
        <!-- Results grid -->
        <div class="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
          <SearchResultCard v-for="plant in searchResults" :key="plant.id" :plant="plant" />
        </div>

        <!-- Pagination -->
        <div v-if="totalPages > 1" class="flex justify-center mt-8">
          <UPagination
            v-model:page="currentPage"
            :items-per-page="itemsPerPage"
            :total="totalResults"
            @update:page="goToPage"
            show-first
            show-last
          />
        </div>
      </div>

      <!-- No results -->
      <div v-else class="text-center py-12">
        <UIcon name="i-material-symbols-search-off-rounded" size="48" class="text-t-muted mb-4" />
        <h3 class="text-xl font-semibold mb-2">Inga resultat hittades - Kontrollera stavningen</h3>
        <p class="text-t-muted mb-6">Du kan söka efter vetenskapligt eller svenskt namn</p>
      </div>
    </div>

    <!-- Initial state -->
    <div v-else class="text-center py-12">
      <UIcon name="i-material-symbols-search-rounded" size="48" class="text-t-muted mb-4" />
      <h3 class="text-xl font-semibold mb-2">Sök efter växter</h3>
      <p class="text-t-muted">
        Använd sökfältet ovan för att hitta växter i vårt register med 170 000+ arter.
      </p>
    </div>
  </div>
</template>
