<script setup lang="ts">
import type { AvailablePlantSimilaritySearchResult } from '~/types/supabase-tables';

const supabase = useSupabaseClient();
const route = useRoute();
const router = useRouter();
const { searchPlants } = useSearch();

const { isMobile, isDesktop } = useScreen();

// URL sort mapping for Swedish URLs
const sortUrlMapping = {
  // Internal -> Swedish URL
  relevance: 'relevans',
  popularity: 'popularitet',
  name_asc: 'namn_az',
  name_desc: 'namn_za',
} as const;

// Reverse mapping for parsing URLs
const sortFromUrl = {
  relevans: 'relevance',
  popularitet: 'popularity',
  namn_az: 'name_asc',
  namn_za: 'name_desc',
} as const;

type InternalSort = 'relevance' | 'popularity' | 'name_asc' | 'name_desc';
type UrlSort = 'relevans' | 'popularitet' | 'namn_az' | 'namn_za';

// Helper functions for URL conversion
const sortToUrl = (sort: InternalSort): UrlSort => sortUrlMapping[sort];
const sortFromUrlParam = (urlSort: string): InternalSort => {
  if (urlSort in sortFromUrl) {
    return sortFromUrl[urlSort as UrlSort];
  }
  // Fallback for backwards compatibility
  if (['relevance', 'popularity', 'name_asc', 'name_desc'].includes(urlSort)) {
    return urlSort as InternalSort;
  }
  return 'popularity'; // Default fallback
};

// Search input, initialized from query param if present
const search = ref(typeof route.query.q === 'string' ? route.query.q : '');
// Filtered plant results from search query
const searchResults = ref<AvailablePlantSimilaritySearchResult[]>([]);
const hasSearched = ref(false);
const totalCount = ref(0);
// Loading and error states
const loading = ref(false);
const errorMsg = ref('');
const searchTime = ref(0);

// Sorting options
const sortBy = ref<'relevance' | 'popularity' | 'name_asc' | 'name_desc'>(
  typeof route.query.sortera === 'string'
    ? (sortFromUrlParam(route.query.sortera) as any)
    : 'popularity' // Will be overridden by watch logic
);

// Computed property to determine available sort options based on search state
const availableSortOptions = computed(() => {
  const hasSearchQuery = search.value.trim().length > 0;

  if (hasSearchQuery) {
    return [
      {
        value: 'relevance',
        label: 'Relevans',
      },
      {
        value: 'popularity',
        label: 'Popularitet',
      },
      {
        value: 'name_asc',
        label: 'Namn (A-Z)',
      },
      {
        value: 'name_desc',
        label: 'Namn (Z-A)',
      },
    ];
  } else {
    return [
      {
        value: 'popularity',
        label: 'Popularitet',
      },
      {
        value: 'name_asc',
        label: 'Namn (A-Z)',
      },
      {
        value: 'name_desc',
        label: 'Namn (Z-A)',
      },
    ];
  }
});

// Watch sortBy changes and auto-adjust if invalid for current state
watch([search, sortBy], ([newSearch, newSortBy]) => {
  const hasSearchQuery = newSearch.trim().length > 0;
  const validOptions = availableSortOptions.value.map((opt) => opt.value);

  if (!validOptions.includes(newSortBy)) {
    if (hasSearchQuery) {
      sortBy.value = 'relevance';
    } else {
      sortBy.value = 'popularity';
    }
  }
});

// Watch for search changes to auto-set default sort
watch(search, (newValue, oldValue) => {
  const hadSearchQuery = oldValue?.trim().length > 0;
  const hasSearchQuery = newValue.trim().length > 0;

  // When transitioning from no search to search, default to relevance
  if (!hadSearchQuery && hasSearchQuery) {
    sortBy.value = 'relevance';
  }
  // When transitioning from search to no search, default to popularity
  else if (hadSearchQuery && !hasSearchQuery) {
    sortBy.value = 'popularity';
  }
});

// Pagination - initialize from URL params
const currentPage = ref(typeof route.query.sida === 'string' ? parseInt(route.query.sida) || 1 : 1);
const itemsPerPage = 60;

// Computed property for total pages
const totalPages = computed(() => Math.ceil(totalCount.value / itemsPerPage));

// Detailed information toggle - persisted in localStorage
const showDetailedInfo = ref(false);

// Initialize detailed info from localStorage on client side
onMounted(() => {
  if (import.meta.client) {
    const stored = localStorage.getItem('detailedInfo');
    showDetailedInfo.value = stored ? JSON.parse(stored) : false;

    // Set initial sort based on whether there's a search query
    const hasInitialSearch = search.value.trim().length > 0;
    if (!route.query.sortera) {
      // Changed to Swedish parameter
      if (hasInitialSearch) {
        sortBy.value = 'relevance';
      } else {
        sortBy.value = 'popularity';
      }
    }
  }
});

// Watch for changes to save to localStorage
watch(showDetailedInfo, (newValue) => {
  if (import.meta.client) {
    localStorage.setItem('detailedInfo', JSON.stringify(newValue));
  }
});

/**
 * High-performance server-side search functionality
 * Shows all plants when no search term, otherwise searches with any length input
 * Uses intelligent sorting: popularity by default when no search, relevance when searching
 */
async function performSearch(immediate = false) {
  loading.value = true;
  errorMsg.value = '';

  // Update URL for deep linking without page reload - include search query, page, and sort
  const query: Record<string, string | undefined> = {
    ...route.query,
    q: search.value || undefined,
    sida: currentPage.value > 1 ? currentPage.value.toString() : undefined,
    sortera: sortBy.value !== 'popularity' ? sortToUrl(sortBy.value) : undefined, // Swedish sort parameter
    sort: undefined, // Remove old English parameter
  };
  router.replace({ query });

  try {
    const offset = (currentPage.value - 1) * itemsPerPage;

    // Use the enhanced search function with sorting
    const result = await searchPlants(search.value || '', {
      limit: itemsPerPage,
      offset,
      includeCount: true, // Include total count for pagination
      sortBy: sortBy.value,
    });

    searchResults.value = result.results;
    totalCount.value = result.totalCount;
    searchTime.value = result.searchTime;
    hasSearched.value = true;
  } catch (error) {
    console.error('Search error:', error);
    errorMsg.value = 'Ett fel uppstod vid sökning. Försök igen.';
    searchResults.value = [];
  } finally {
    loading.value = false;
  }
}

// Trigger search on button click or Enter key
function onSearch() {
  currentPage.value = 1; // Reset to first page
  performSearch(true);
}

// Handle sort change
function onSortChange() {
  currentPage.value = 1; // Reset to first page when sorting changes
  performSearch(true);
}

// Handle pagination
function goToPage(page: number) {
  if (page < 1 || page > totalPages.value) return;
  currentPage.value = page;
  performSearch(true);
  // Scroll to top of results
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

// Load search results on mount - always load plants (all plants if no search, filtered if search exists)
onMounted(async () => {
  // Load plants on initial page load - either search results or all plants
  performSearch(true);
});

// Watch for changes in the route query (e.g., browser navigation)
watch(
  () => route.query,
  (newQuery) => {
    const newQ = newQuery.q;
    const newPage = newQuery.sida;
    const newSort = newQuery.sortera; // Changed to Swedish parameter

    // Handle search query changes
    if (typeof newQ === 'string' && newQ !== search.value) {
      search.value = newQ;
    }

    // Handle page changes
    const pageNum = typeof newPage === 'string' ? parseInt(newPage) || 1 : 1;
    if (pageNum !== currentPage.value) {
      currentPage.value = pageNum;
    }

    // Handle sort changes - convert from Swedish URL to internal format
    if (typeof newSort === 'string') {
      const internalSort = sortFromUrlParam(newSort);
      if (
        ['relevance', 'popularity', 'name_asc', 'name_desc'].includes(internalSort) &&
        internalSort !== sortBy.value
      ) {
        sortBy.value = internalSort as any;
      }
    } else if (!newSort && sortBy.value !== 'popularity') {
      sortBy.value = 'popularity'; // Default sort
    }

    // Always perform search (will show all plants if no search term)
    performSearch(true);
  },
  { deep: true }
);

// When search is cleared, show all plants instead of clearing results
watch(search, (newValue) => {
  if (newValue.length === 0) {
    // Don't clear results, instead show all plants
    currentPage.value = 1; // Reset to first page
    // Reset sort to popularity when clearing search
    if (sortBy.value === 'relevance') {
      sortBy.value = 'popularity';
    }
    performSearch(true); // This will show all plants since search is empty
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
          @blur="isMobile ? onSearch() : null"
          :ui="{
            root: 'w-full',

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
        class="max-sm:hidden"
        :loading="loading"
        :disabled="loading"
      >
        Sök
      </UButton>
      <USelect
        v-model="sortBy"
        :items="availableSortOptions"
        value-attribute="value"
        option-attribute="label"
        size="xl"
        @change="onSortChange"
        class="max-sm:w-full w-40"
        icon="i-material-symbols-sort"
      />
    </div>

    <!-- Sort controls -->
    <!-- <div
      class="flex items-center justify-between mb-4 max-sm:flex-col max-sm:items-start max-sm:gap-2"
    >
      <div class="flex items-center gap-3">
        <span class="text-sm text-t-muted font-medium">Sortera:</span>
      </div>
      <div class="flex items-center gap-2 mb-2">
        <USwitch v-model="showDetailedInfo" size="xs" />
        <span class="text-sm text-t-muted">Detaljerad information</span>
      </div>
      <div class="flex items-center gap-2 mb-2">
        <USwitch v-model="showDetailedInfo" size="xs" />
        <span class="text-sm text-t-muted">Detaljerad information</span>
      </div>
    </div> -->

    <!-- Search results info -->
    <div v-if="hasSearched && !loading" class="mb-6">
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2">
        <p class="text-t-muted">
          <span v-if="searchResults.length > 0">
            Visar {{ (currentPage - 1) * itemsPerPage + 1 }}-{{
              Math.min(currentPage * itemsPerPage, totalCount)
            }}
            av {{ totalCount.toLocaleString() }} resultat
          </span>
          <span v-else> Inga resultat </span>
        </p>
        <!-- <p v-if="searchTime > 0" class="text-sm text-t-muted">
          Söktid: {{ Math.round(searchTime) }}ms
        </p> -->
        <div class="flex items-center gap-2 mb-2">
          <USwitch v-model="showDetailedInfo" size="xs" />
          <span class="text-sm text-t-muted">Detaljerad information</span>
        </div>
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
          <SearchResultCard
            v-for="plant in searchResults"
            :key="plant.id"
            :plant="plant"
            :show-detailed="showDetailedInfo"
          />
        </div>
        <!-- Pagination -->
        <div v-if="totalPages > 1" class="flex justify-center mt-8">
          <UPagination
            v-model:page="currentPage"
            :items-per-page="itemsPerPage"
            :total="totalCount"
            :show-last="true"
            :show-first="true"
            size="md"
            @update:page="goToPage"
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

    <!-- Initial state - only show when no search has been performed yet -->
    <div v-else class="text-center py-12">
      <UIcon name="i-material-symbols-search-rounded" size="48" class="text-t-muted mb-4" />
      <h3 class="text-xl font-semibold mb-2">Laddar växter...</h3>
      <p class="text-t-muted">
        Visar alla tillgängliga växter. Använd sökfältet för att filtrera bland 170 000+ arter.
      </p>
    </div>
  </div>
</template>
