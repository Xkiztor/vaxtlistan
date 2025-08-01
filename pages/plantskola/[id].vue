<script setup lang="ts">
import type { Plantskola, Facit } from '~/types/supabase-tables';
import { DynamicScroller, DynamicScrollerItem } from 'vue-virtual-scroller';
import 'vue-virtual-scroller/dist/vue-virtual-scroller.css';
import Fuse from 'fuse.js';

// Page metadata for SEO
definePageMeta({
  title: 'Plantskola',
  description: 'Upptäck plantskolor och deras växtutbud på Växtlistan',
});

// Get route parameters
const route = useRoute();
const plantskolaId = computed(() => parseInt(route.params.id as string));

// Initialize Supabase client
const supabase = useSupabaseClient();

// Types for data structure
interface PlantskolaWithPlants extends Plantskola {
  total_plants: number;
  verified_plants: number;
  plant_categories: { type: string; count: number }[];
}

interface PlantWithFacit {
  id: number;
  facit_id: number;
  name_by_plantskola: string;
  comment_by_plantskola?: string;
  pot?: string;
  height?: string;
  price?: number;
  stock?: number;
  hidden: boolean;
  own_columns?: Record<string, any>;
  // Facit data
  facit_name: string;
  facit_sv_name?: string;
  facit_plant_type?: string;
  facit_rhs_types?: number[];
  facit_height?: string;
  facit_spread?: string;
  facit_colors?: string[];
  facit_season_of_interest?: number[];
  facit_sunlight?: number[];
  facit_images?: any[];
}

interface PlantRow {
  id: string;
  plants: (PlantWithFacit | null)[];
  index: number;
}

// Fetch plantskola data with async data
const { data: plantskola, error: plantskolaError } = await useAsyncData(
  `plantskola-${plantskolaId.value}`,
  async () => {
    // First fetch basic plantskola information
    const { data: basicData, error: basicError } = await supabase
      .from('plantskolor')
      .select('*')
      .eq('id', plantskolaId.value)
      .eq('hidden', false)
      .single();

    if (basicError || !basicData) {
      throw createError({
        statusCode: 404,
        statusMessage: 'Plantskola not found',
      });
    }

    // Fetch statistics about plants
    const { data: statsData } = await supabase
      .from('totallager')
      .select(
        `
        id,
        facit_id,
        hidden,
        facit!inner(plant_type, rhs_types)
      `
      )
      .eq('plantskola_id', plantskolaId.value);

    // Calculate statistics
    const totalPlants = statsData?.length || 0;
    const visiblePlants = statsData?.filter((p: any) => !p.hidden).length || 0;

    // Group by plant types for categories
    const typeGroups =
      statsData?.reduce((acc: Record<string, number>, plant: any) => {
        const plantType = plant.facit?.plant_type || 'Okänd';
        acc[plantType] = (acc[plantType] || 0) + 1;
        return acc;
      }, {} as Record<string, number>) || {};

    const plantCategories = Object.entries(typeGroups)
      .map(([type, count]) => ({ type, count }))
      .sort((a, b) => b.count - a.count);

    return {
      ...(basicData as Plantskola),
      total_plants: totalPlants,
      verified_plants: visiblePlants,
      plant_categories: plantCategories,
    } as PlantskolaWithPlants;
  },
  {
    lazy: true,
  }
);

// Handle error state
if (plantskolaError.value) {
  throw createError({
    statusCode: 404,
    statusMessage: 'Plantskola kunde inte hittas',
  });
}

// Reactive search - client-side with Fuse.js
const searchQuery = ref('');

// View mode toggle - list or grid with localStorage persistence
const viewMode = ref<'list' | 'grid'>('grid');

// Load saved view mode from localStorage on client
onMounted(() => {
  if (process.client) {
    const savedViewMode = localStorage.getItem('plantskola-view-mode');
    if (savedViewMode === 'grid' || savedViewMode === 'list') {
      viewMode.value = savedViewMode;
    }
  }
});

// Save view mode to localStorage when it changes
watch(viewMode, (newMode) => {
  if (process.client) {
    localStorage.setItem('plantskola-view-mode', newMode);
  }
});

// Sorting options and state
const sortOptions = [
  { value: 'name-asc', label: 'Namn (A-Z)', key: 'facit_name', order: 'asc' },
  { value: 'name-desc', label: 'Namn (Z-A)', key: 'facit_name', order: 'desc' },
  {
    value: 'price-asc',
    label: 'Billigast först',
    key: 'price',
    order: 'asc',
  },
  {
    value: 'price-desc',
    label: 'Dyrast först',
    key: 'price',
    order: 'desc',
  },
  {
    value: 'stock-desc',
    label: 'Lagersaldo (Högst först)',
    key: 'stock',
    order: 'desc',
  },
  {
    value: 'stock-asc',
    label: 'Lagersaldo (Lägst först)',
    key: 'stock',
    order: 'asc',
  },
];

const selectedSort = ref('name-asc');

// Load saved view mode from localStorage on client
onMounted(() => {
  if (process.client) {
    const savedViewMode = localStorage.getItem('plantskola-view-mode');
    if (savedViewMode === 'grid' || savedViewMode === 'list') {
      viewMode.value = savedViewMode;
    }
  }
});

// Fetch all plants without any filtering
const { data: allPlants, pending: plantsLoading } = await useAsyncData(
  `plantskola-plants-${plantskolaId.value}`,
  async () => {
    const query = supabase
      .from('totallager')
      .select(
        `
        id,
        facit_id,
        name_by_plantskola,
        comment_by_plantskola,
        pot,
        height,
        price,
        stock,
        hidden,
        own_columns,
        facit!inner(
          name,
          sv_name,
          plant_type,
          rhs_types,
          height,
          spread,
          colors,
          season_of_interest,
          sunlight,
          images
        )
      `
      )
      .eq('plantskola_id', plantskolaId.value)
      .eq('hidden', false)
      .order('name_by_plantskola', { ascending: true });

    const { data, error } = await query;

    if (error) {
      console.error('Error fetching plants:', error);
      return [];
    }

    return (
      data?.map((item: any) => ({
        ...item,
        facit_name: item.facit?.name,
        facit_sv_name: item.facit?.sv_name,
        facit_plant_type: item.facit?.plant_type,
        facit_rhs_types: item.facit?.rhs_types,
        facit_height: item.facit?.height,
        facit_spread: item.facit?.spread,
        facit_colors: item.facit?.colors,
        facit_season_of_interest: item.facit?.season_of_interest,
        facit_sunlight: item.facit?.sunlight,
        facit_images: item.facit?.images,
      })) || []
    );
  },
  {
    lazy: true,
  }
);

// Configure Fuse.js for fuzzy search
const fuseOptions = {
  keys: [
    {
      name: 'name_by_plantskola',
      weight: 1.0,
    },
    {
      name: 'facit_name',
      weight: 0.8,
    },
    {
      name: 'facit_sv_name',
      weight: 0.9,
    },
    {
      name: 'facit_plant_type',
      weight: 0.6,
    },
    {
      name: 'comment_by_plantskola',
      weight: 0.4,
    },
  ],
  threshold: 0.3, // Lower = more strict matching
  distance: 100,
  minMatchCharLength: 2,
  includeScore: true,
  includeMatches: true,
};

// Create Fuse instance
const fuse = computed(() => {
  if (!allPlants.value?.length) return null;
  return new Fuse(allPlants.value, fuseOptions);
});

// Helper function to sort plants
const sortPlants = (plantsToSort: PlantWithFacit[]) => {
  if (!plantsToSort.length) return plantsToSort;

  const currentSort = sortOptions.find((opt) => opt.value === selectedSort.value);
  if (!currentSort) return plantsToSort;

  return [...plantsToSort].sort((a, b) => {
    let aValue = a[currentSort.key as keyof PlantWithFacit];
    let bValue = b[currentSort.key as keyof PlantWithFacit];

    // Handle null/undefined values - put them at the end
    if (aValue == null && bValue == null) return 0;
    if (aValue == null) return 1;
    if (bValue == null) return -1;

    // Handle numeric fields (price and stock)
    if (currentSort.key === 'price' || currentSort.key === 'stock') {
      const aNum = Number(aValue);
      const bNum = Number(bValue);

      // Handle NaN values (invalid numbers) - put them at the end
      if (isNaN(aNum) && isNaN(bNum)) return 0;
      if (isNaN(aNum)) return 1;
      if (isNaN(bNum)) return -1;

      if (currentSort.order === 'asc') {
        return aNum - bNum;
      } else {
        return bNum - aNum;
      }
    }

    // Handle text fields (names, etc.)
    const aText = String(aValue).toLowerCase();
    const bText = String(bValue).toLowerCase();

    if (currentSort.order === 'asc') {
      return aText < bText ? -1 : aText > bText ? 1 : 0;
    } else {
      return aText > bText ? -1 : aText < bText ? 1 : 0;
    }
  });
};

// Filtered and sorted plants based on search and sort selection
const plants = computed(() => {
  if (!allPlants.value?.length) return [];

  let filteredPlants;

  // If no search query, use all plants
  if (!searchQuery.value.trim()) {
    filteredPlants = allPlants.value;
  } else {
    // Use Fuse.js for fuzzy search
    if (!fuse.value) return [];
    const results = fuse.value.search(searchQuery.value.trim());
    filteredPlants = results.map((result) => result.item);
  }

  // Apply sorting
  return sortPlants(filteredPlants);
});

// Client-side search is instant, no debouncing needed

// Screen detection for responsive behavior
const { isMobile, isTablet, isDesktop, isLargeDesktop, clientReady } = useScreen();
const { width, height } = useWindowSize();

// Virtual scroller configuration
const dynamicScrollerRef = ref<InstanceType<typeof DynamicScroller>>();
const virtualScrollerHeight = ref(600); // Default height

// Calculate dynamic height based on available space
const calculateScrollerHeight = () => {
  if (process.client) {
    const viewport = height.value;
    let navbarHeight = 80; // Approximate height of navbar
    let topPadding = 16; // Header section with plantskola info
    let searchHeight = 90; // Search section
    let bottomPadding = 32; // Bottom padding for scroller

    if (width.value <= 768) {
      // Mobile view adjustments
      navbarHeight = 80;
      topPadding = 16; // Mobile header is taller
      searchHeight = 90; // Mobile search section is taller
      bottomPadding = 32;
    }

    const totalUsedHeight = navbarHeight + topPadding + searchHeight + bottomPadding;
    virtualScrollerHeight.value = Math.max(400, viewport - totalUsedHeight);
  }
};

// Grid layout configuration
const gridColumns = computed(() => {
  if (!clientReady.value) return 1; // Default during SSR
  if (isLargeDesktop.value) return 4; // xl: 4 columns
  if (isDesktop.value) return 3; // lg: 3 columns
  if (isTablet.value) return 2; // md: 2 columns
  return 1; // sm: 1 column
});

// Group plants into rows for grid display
const plantsInRows = computed(() => {
  if (viewMode.value !== 'grid' || !plants.value?.length) return [];

  const cols = gridColumns.value;
  const rows: PlantRow[] = [];

  for (let i = 0; i < plants.value.length; i += cols) {
    const row: (PlantWithFacit | null)[] = plants.value.slice(i, i + cols);
    // Pad the last row with null values if needed to maintain consistent structure
    while (row.length < cols) {
      row.push(null);
    }
    rows.push({
      id: `row-${i}`,
      plants: row,
      index: Math.floor(i / cols),
    });
  }

  return rows;
});

// Get the items for virtual scroller based on view mode
const virtualScrollerItems = computed(() => {
  return viewMode.value === 'grid' ? plantsInRows.value : plants.value;
});

// Get minimum item size based on view mode
const minItemSize = computed(() => {
  return viewMode.value === 'grid' ? 280 : 100;
});

// Update scroller height on mount and resize
onMounted(() => {
  calculateScrollerHeight();
  window.addEventListener('resize', calculateScrollerHeight);
});

onUnmounted(() => {
  window.removeEventListener('resize', calculateScrollerHeight);
});

// Reset scroll position when search, view mode, or sort changes
watch([searchQuery, viewMode, selectedSort], () => {
  // Reset scroll position when search, view mode, or sort changes
  if (dynamicScrollerRef.value && 'scrollToTop' in dynamicScrollerRef.value) {
    (dynamicScrollerRef.value as any).scrollToTop();
  }
});

// Format price function
const formatPrice = (price: number | null | undefined): string => {
  if (!price) return 'Pris på förfrågan';
  return new Intl.NumberFormat('sv-SE', {
    style: 'currency',
    currency: 'SEK',
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  }).format(price);
};

// Format contact info
const formatPhone = (phone: string): string => {
  return phone.replace(/(\d{3})(\d{3})(\d{2})(\d{2})/, '$1-$2 $3 $4');
};

// Helper function to format custom fields from own_columns
const formatCustomFields = (ownColumns: Record<string, any> | null | undefined) => {
  if (!ownColumns || typeof ownColumns !== 'object') return [];

  return Object.entries(ownColumns)
    .filter(([_, value]) => value != null && value !== '')
    .map(([key, value]) => ({
      key,
      value: String(value).trim(),
      displayKey: key.charAt(0).toUpperCase() + key.slice(1).replace(/_/g, ' '),
    }));
};

// Helper function to get the first image URL from facit images
const getFirstImageUrl = (facitImages: any[] | null | undefined): string | null => {
  if (!facitImages || !Array.isArray(facitImages) || facitImages.length === 0) {
    return null;
  }

  const firstImage = facitImages[0];
  if (firstImage && typeof firstImage === 'object' && firstImage.url) {
    return firstImage.url;
  }

  return null;
};

// SEO meta tags
useHead({
  title: `${plantskola.value?.name} - Plantskola | Växtlistan`,
  meta: [
    {
      name: 'description',
      content: `Upptäck ${plantskola.value?.name} och deras växtutbud med ${
        plantskola.value?.total_plants
      } växter. ${plantskola.value?.description || ''}`,
    },
    {
      property: 'og:title',
      content: `${plantskola.value?.name} - Plantskola | Växtlistan`,
    },
    {
      property: 'og:description',
      content: `Plantskola med ${plantskola.value?.total_plants} växter. ${
        plantskola.value?.description || ''
      }`,
    },
    {
      property: 'og:type',
      content: 'website',
    },
  ],
});
</script>

<template>
  <div class="min-h-screen">
    <!-- Error state -->
    <div v-if="plantskolaError" class="flex items-center justify-center min-h-[400px]">
      <UCard class="max-w-md">
        <div class="text-center">
          <UIcon
            name="i-heroicons-exclamation-triangle"
            class="w-12 h-12 mx-auto mb-4 text-warning"
          />
          <h2 class="text-xl font-semibold mb-2">Plantskola hittades inte</h2>
          <p class="text-muted mb-4">
            Den begärda plantskolan kunde inte hittas eller är inte tillgänglig.
          </p>
          <UButton to="/" color="primary"> Tillbaka till startsidan </UButton>
        </div>
      </UCard>
    </div>

    <!-- Main content -->
    <div v-else-if="plantskola" class="container mx-auto px-4 py-8 md:px-6 lg:px-8 max-w-7xl">
      <!-- Header section -->
      <section class="mb-8">
        <div class="">
          <div class="flex flex-col lg:flex-row gap-4 lg:gap-8">
            <!-- Plantskola info -->
            <div class="flex-1">
              <h1 class="text-3xl lg:text-4xl font-bold mb-1 lg:mb-2">
                {{ plantskola.name }}
              </h1>

              <!-- Description -->
              <p v-if="plantskola.description" class="text-lg text-regular leading-relaxed">
                {{ plantskola.description }}
              </p>

              <!-- Services -->
              <div class="flex flex-wrap gap-2 mt-4">
                <UBadge v-if="plantskola.postorder" color="info" variant="subtle">
                  <UIcon name="i-heroicons-truck" class="w-4 h-4 mr-1" />
                  Postorder
                </UBadge>
                <UBadge v-if="plantskola.on_site" color="success" variant="subtle">
                  <UIcon name="i-heroicons-map-pin" class="w-4 h-4 mr-1" />
                  Hämta på plats
                </UBadge>
              </div>
            </div>

            <!-- Contact information sidebar -->
            <div class="">
              <div class="rounded-lg p-4 border border-border">
                <div class="space-y-4">
                  <!-- Address -->
                  <div v-if="plantskola.adress" class="flex items-center gap-4">
                    <UIcon name="i-heroicons-map-pin" class="w-5 h-5 text-muted mt-0.5" />
                    <div class="flex-1 leading-tight">
                      <div class="font-medium text-sm">Adress</div>
                      <div class="text-regular text-sm">
                        {{ plantskola.adress }}
                      </div>
                    </div>
                  </div>

                  <!-- Phone -->
                  <div v-if="plantskola.phone" class="flex items-center gap-4">
                    <UIcon name="i-heroicons-phone" class="w-5 h-5 text-muted mt-0.5" />
                    <div class="flex-1 leading-tight">
                      <div class="font-medium text-sm">Telefon</div>
                      <ULink
                        :to="`tel:${plantskola.phone}`"
                        class="text-link hover:underline text-sm"
                      >
                        {{ formatPhone(plantskola.phone) }}
                      </ULink>
                    </div>
                  </div>

                  <!-- Email -->
                  <div v-if="plantskola.email" class="flex items-center gap-4">
                    <UIcon name="i-heroicons-envelope" class="w-5 h-5 text-muted mt-0.5" />
                    <div class="flex-1 leading-tight">
                      <div class="font-medium text-sm">E-post</div>
                      <ULink
                        :to="`mailto:${plantskola.email}`"
                        class="text-link hover:underline break-all text-sm"
                      >
                        {{ plantskola.email }}
                      </ULink>
                    </div>
                  </div>

                  <!-- Website -->
                  <div v-if="plantskola.url" class="flex items-center gap-4">
                    <UIcon name="i-heroicons-globe-alt" class="w-5 h-5 text-muted mt-0.5" />
                    <div class="flex-1 leading-tight">
                      <div class="font-medium text-sm">Webbsida</div>
                      <ULink
                        :to="plantskola.url"
                        target="_blank"
                        class="text-link hover:underline break-all text-sm inline-flex items-center gap-1"
                      >
                        {{ plantskola.url.replace(/^https?:\/\//, '') }}
                        <UIcon name="i-heroicons-arrow-top-right-on-square" class="w-3 h-3" />
                      </ULink>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>
      <!-- Plants section -->
      <section>
        <div class="">
          <!-- Section header with search and view toggle -->
          <div class="pb-2 max-md:border-b max-md:border-border">
            <div class="flex items-end gap-4 mb-3">
              <h2 class="text-2xl font-bold leading-none">Växtutbud</h2>
              <!-- Search result count -->
              <div v-if="plants?.length" class="text-sm text-t-muted leading-tight">
                <span v-if="searchQuery.trim()">
                  {{ plants.length }} resultat
                  <span v-if="plants.length === 1">({{ plants[0].facit_name }})</span>
                </span>
                <span v-else> {{ plants.length }} växter </span>
              </div>
            </div>
            <div class="flex flex-col sm:flex-row sm:gap-2 sm:items-center">
              <!-- Search input -->
              <div class="flex-1 relative">
                <UInput
                  v-model="searchQuery"
                  placeholder="Sök bland växter..."
                  icon="i-heroicons-magnifying-glass"
                  size="lg"
                  class="w-full"
                />
                <!-- Search indicator -->
                <div
                  v-if="searchQuery.trim() && plants.length > 0"
                  class="absolute right-3 top-1/2 transform -translate-y-1/2"
                >
                  <UIcon name="i-heroicons-check-circle" class="w-5 h-5 text-success" />
                </div>
              </div>
              <!-- View toggle and sorting controls -->
              <div class="flex items-center gap-3 max-sm:mt-2">
                <!-- Sort dropdown -->
                <USelect
                  v-model="selectedSort"
                  :items="sortOptions"
                  option-attribute="label"
                  value-attribute="value"
                  class="w-48 max-sm:w-full text-t-regular"
                  size="md"
                >
                  <template #leading>
                    <UIcon name="i-heroicons-arrows-up-down" class="w-4 h-4" />
                  </template>
                </USelect>

                <!-- View toggle buttons with sliding animation -->
                <div
                  class="relative grid grid-cols-2 rounded-lg p-1 border border-border max-sm:hidden"
                >
                  <!-- Sliding indicator background -->
                  <div
                    class="absolute top-1 bottom-1 rounded-md border border-border bg-bg-elevated transition-all duration-300 ease-out"
                    :class="{
                      'left-1 right-1/2 mr-0.5': viewMode === 'list',
                      'right-1 left-1/2 ml-0.5': viewMode === 'grid',
                    }"
                  />

                  <!-- Toggle buttons -->
                  <button
                    @click="viewMode = 'list'"
                    class="relative z-10 flex items-center gap-1.5 px-3 py-[3px] text-sm font-medium transition-colors duration-300 ease-out rounded-md"
                    :class="{
                      '': viewMode === 'list',
                      'text-t-toned': viewMode !== 'list',
                    }"
                    :aria-pressed="viewMode === 'list'"
                    aria-label="Visa som lista"
                  >
                    <UIcon name="i-heroicons-list-bullet" class="w-4 h-4" />
                    <span>Lista</span>
                  </button>

                  <button
                    @click="viewMode = 'grid'"
                    class="relative z-10 flex items-center gap-1.5 px-3 py-[3px] text-sm font-medium transition-colors duration-300 ease-out rounded-md"
                    :class="{
                      '': viewMode === 'grid',
                      'text-t-toned': viewMode !== 'grid',
                    }"
                    :aria-pressed="viewMode === 'grid'"
                    aria-label="Visa som rutnät"
                  >
                    <UIcon name="i-heroicons-squares-2x2" class="w-4 h-4" />
                    <span>Rutnät</span>
                  </button>
                </div>
              </div>

              <!-- Mobile view toggle (separate row) -->
              <div class="sm:hidden mt-2 flex justify-center">
                <div class="relative grid grid-cols-2 rounded-lg p-1 border border-border w-full">
                  <!-- Sliding indicator background -->
                  <div
                    class="absolute top-1 bottom-1 rounded-md border border-border bg-bg-elevated transition-all duration-300 ease-out"
                    :class="{
                      'left-1 right-1/2 mr-0.5': viewMode === 'list',
                      'right-1 left-1/2 ml-0.5': viewMode === 'grid',
                    }"
                  />

                  <!-- Toggle buttons -->
                  <button
                    @click="viewMode = 'list'"
                    class="relative z-10 flex justify-center items-center gap-1.5 px-3 py-1.5 text-sm font-medium transition-colors duration-300 ease-out rounded-md"
                    :class="{
                      '': viewMode === 'list',
                      'text-t-toned': viewMode !== 'list',
                    }"
                    :aria-pressed="viewMode === 'list'"
                    aria-label="Visa som lista"
                  >
                    <UIcon name="i-heroicons-list-bullet" class="w-4 h-4" />
                    <span>Lista</span>
                  </button>

                  <button
                    @click="viewMode = 'grid'"
                    class="relative z-10 flex justify-center items-center gap-1.5 px-3 py-1.5 text-sm font-medium transition-colors duration-300 ease-out rounded-md"
                    :class="{
                      '': viewMode === 'grid',
                      'text-t-toned': viewMode !== 'grid',
                    }"
                    :aria-pressed="viewMode === 'grid'"
                    aria-label="Visa som rutnät"
                  >
                    <UIcon name="i-heroicons-squares-2x2" class="w-4 h-4" />
                    <span>Rutnät</span>
                  </button>
                </div>
              </div>
            </div>
          </div>
          <!-- List Header -->
          <div v-if="viewMode === 'list'" class="max-md:hidden flex mb-1 mt-1 px-2 gap-4">
            <div class="w-16 pl-1 text-sm text-t-muted">Bild</div>
            <div
              class="grid grid-cols-[1fr_6rem_6rem_6rem] lg:grid-cols-[5fr_1fr_1fr_1.2fr] gap-1 w-full"
            >
              <span class="text-sm text-t-muted">Namn</span>
              <span class="text-sm text-t-muted">Kruka</span>
              <span class="text-sm text-t-muted">Höjd</span>
              <span class="text-right text-sm text-t-muted pr-1">Pris</span>
            </div>
          </div>
          <!-- Plants list -->
          <div class="">
            <!-- Loading state -->
            <div v-if="plantsLoading" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              <USkeleton v-for="i in 6" :key="i" class="h-48 rounded-lg" />
            </div>
            <!-- No results -->
            <div v-else-if="!plants?.length" class="text-center py-12">
              <UIcon
                name="i-heroicons-magnifying-glass"
                class="w-12 h-12 mx-auto mb-4 text-muted"
              />
              <h3 class="text-lg font-medium mb-2">
                <span v-if="searchQuery.trim()">Inga sökresultat</span>
                <span v-else>Inga växter hittades</span>
              </h3>
              <p class="text-muted">
                <span v-if="searchQuery.trim()">
                  Inga växter matchade din sökning "<strong>{{ searchQuery }}</strong
                  >". Prova med andra sökord.
                </span>
                <span v-else> Denna plantskola har för närvarande inga växter tillgängliga. </span>
              </p>
            </div>
            <!-- Virtual Scroller for Plants -->
            <div v-else class="md:border md:border-border md:rounded-lg overflow-hidden">
              <DynamicScroller
                ref="dynamicScrollerRef"
                class="scroller"
                :items="virtualScrollerItems"
                :min-item-size="minItemSize"
                :style="{ height: virtualScrollerHeight + 'px' }"
                :key-field="viewMode === 'grid' ? 'id' : 'id'"
                v-slot="{ item, index, active }"
              >
                <DynamicScrollerItem
                  :item="item"
                  :active="active"
                  :size-dependencies="
                    viewMode === 'grid'
                      ? [
                          item.plants?.length,
                          gridColumns,
                          ...item.plants?.filter(Boolean).map((p: any) => p?.facit_name || '') || [],
                          ...item.plants?.filter(Boolean).map((p: any) => getFirstImageUrl(p?.facit_images) || '') || []
                        ]
                      : [
                          item.facit_name,
                          item.facit_sv_name,
                          item.name_by_plantskola,
                          item.comment_by_plantskola,
                          item.pot,
                          item.height,
                          item.price,
                          item.stock,
                          getFirstImageUrl(item.facit_images) || '',
                        ]
                  "
                  :data-index="index"
                  :data-active="active"
                >
                  <!-- List View -->
                  <div
                    v-if="viewMode === 'list'"
                    class="border-b border-border py-4 md:p-2 md:hover:bg-bg-elevated transition-colors duration-200"
                  >
                    <div class="flex flex-row items-start gap-3 md:gap-4">
                      <!-- Plant image -->
                      <ULink
                        :to="`/vaxt/${item.facit_id}/${encodeURIComponent(item.facit_name)}`"
                        class="w-14 h-14 md:w-16 md:h-16 bg-bg-elevated rounded-lg flex-shrink-0 overflow-hidden border border-border"
                      >
                        <img
                          v-if="getFirstImageUrl(item.facit_images)"
                          :src="getFirstImageUrl(item.facit_images)!"
                          :alt="item.facit_name"
                          class="w-full h-full object-cover hover:scale-105 transition-transform duration-200"
                          loading="lazy"
                        />
                        <div v-else class="w-full h-full grid place-items-center">
                          <UIcon
                            name="f7:tree"
                            :size="isMobile ? '18' : '20'"
                            class="text-t-muted opacity-70"
                          />
                        </div>
                      </ULink>

                      <!-- Mobile -->
                      <div class="flex-1 md:hidden">
                        <div class="flex-1 flex flex-row min-w-0 gap-2">
                          <!-- Plant name and link -->
                          <div class="flex flex-col justify-center">
                            <ULink
                              :to="`/vaxt/${item.facit_id}/${encodeURIComponent(item.facit_name)}`"
                              class="text-t-regular hover:underline"
                            >
                              <h3 class="font-semibold text-base md:text-lg leading-tight">
                                {{ item.facit_name }}
                              </h3>
                            </ULink>
                            <p v-if="item.facit_sv_name" class="text-sm text-t-muted">
                              {{ item.facit_sv_name }}
                            </p>
                            <p
                              v-if="item.facit_name && item.name_by_plantskola !== item.facit_name"
                              class="text-xs text-t-muted italic"
                            >
                              ({{ item.name_by_plantskola }})
                            </p>
                          </div>
                          <p
                            v-if="item.comment_by_plantskola"
                            class="text-sm text-t-muted italic md:line-clamp-2 max-md:hidden"
                          >
                            {{ item.comment_by_plantskola }}
                          </p>
                          <!-- Price and stock info -->
                          <div
                            class="flex flex-col items-end leading-tight ml-auto min-w-max"
                            v-if="item.price || item.stock"
                          >
                            <span v-if="item.price" class="font-bold text-sm md:text-base">
                              {{ formatPrice(item.price) }}
                            </span>
                            <span v-if="item.stock" class="text-t-toned text-sm">
                              <span class="font-semibold">{{ item.stock }}</span>
                              st i lager
                            </span>
                          </div>
                        </div>
                        <div
                          class="flex flex-wrap gap-1 md:hidden pt-1"
                          v-if="item.pot || item.height || item.own_columns"
                        >
                          <UBadge
                            v-if="item.pot"
                            color="neutral"
                            variant="soft"
                            class="text-xs max-h-max"
                          >
                            Kruka: {{ item.pot }}
                          </UBadge>
                          <UBadge
                            v-if="item.height"
                            color="neutral"
                            variant="soft"
                            class="text-xs max-h-max"
                          >
                            Höjd: {{ item.height }}
                          </UBadge>
                          <UBadge
                            v-for="field in formatCustomFields(item.own_columns)"
                            :key="field.key"
                            color="primary"
                            variant="soft"
                            class="text-xs max-h-max"
                          >
                            {{ field.displayKey }}: {{ field.value }}
                          </UBadge>
                        </div>
                        <p
                          v-if="item.comment_by_plantskola"
                          class="text-sm text-t-muted italic md:hidden pt-1"
                        >
                          {{ item.comment_by_plantskola }}
                        </p>
                      </div>

                      <!--  -->
                      <!-- Desktop -->
                      <!--  -->
                      <div class="flex-1 max-md:hidden">
                        <div
                          class="grid grid-cols-[1fr_6rem_6rem_6rem] lg:grid-cols-[5fr_1fr_1fr_1.2fr] gap-1"
                        >
                          <!-- Plant name and link -->
                          <div class="flex flex-col justify-center">
                            <ULink
                              :to="`/vaxt/${item.facit_id}/${encodeURIComponent(item.facit_name)}`"
                              class="text-t-regular hover:underline"
                            >
                              <h3 class="font-semibold text-base md:text-lg leading-tight">
                                {{ item.facit_name }}
                              </h3>
                            </ULink>
                            <p v-if="item.facit_sv_name" class="text-sm text-t-muted">
                              {{ item.facit_sv_name }}
                            </p>
                            <p
                              v-if="item.facit_name && item.name_by_plantskola !== item.facit_name"
                              class="text-xs text-t-muted italic"
                            >
                              ({{ item.name_by_plantskola }})
                            </p>
                          </div>
                          <!-- Plant attributes with badges -->
                          <span class="text-base">{{ item.pot }} </span>
                          <span class="text-base">{{ item.height }}</span>

                          <!-- Custom fields from plantskola -->
                          <!-- <div
                            v-if="formatCustomFields(item.own_columns).length > 0"
                            class="flex flex-wrap gap-1 mb-2"
                          >
                          </div> -->

                          <!-- Price and stock info -->
                          <div
                            class="flex flex-col items-end leading-tight ml-auto min-w-max"
                            v-if="item.price || item.stock"
                          >
                            <span v-if="item.price" class="font-bold text-sm md:text-base">
                              {{ formatPrice(item.price) }}
                            </span>
                            <span v-if="item.stock" class="text-t-toned text-sm">
                              <span class="font-semibold">{{ item.stock }}</span>
                              st i lager
                            </span>
                          </div>
                        </div>
                        <!-- Bottom part -->
                        <div class="flex flex-wrap gap-1 pt-1">
                          <p
                            v-if="item.comment_by_plantskola"
                            class="text-sm text-t-muted italic md:line-clamp-2 max-md:hidden"
                          >
                            {{ item.comment_by_plantskola }}
                          </p>
                          <UBadge
                            v-for="field in formatCustomFields(item.own_columns)"
                            :key="field.key"
                            color="primary"
                            variant="soft"
                            class="text-xs max-h-max"
                          >
                            {{ field.displayKey }}: {{ field.value }}
                          </UBadge>
                        </div>
                      </div>
                    </div>
                  </div>
                  <!-- --------- -->
                  <!-- Grid View -->
                  <!------------ -->
                  <div v-else class="p-2 md:p-4">
                    <div
                      class="grid gap-3 md:gap-4"
                      :class="{
                        'grid-cols-1': gridColumns === 1,
                        'grid-cols-2': gridColumns === 2,
                        'grid-cols-3': gridColumns === 3,
                        'grid-cols-4': gridColumns === 4,
                      }"
                    >
                      <!-- Plant card for each column -->
                      <div
                        v-for="(plant, colIndex) in item.plants"
                        :key="plant ? plant.id : `empty-${item.index}-${colIndex}`"
                        class="w-full"
                      >
                        <div v-if="plant" class="h-full">
                          <div class="flex flex-col h-full">
                            <!-- Plant image -->
                            <ULink
                              :to="`/vaxt/${plant.facit_id}/${encodeURIComponent(
                                plant.facit_name
                              )}`"
                              class="w-full aspect-[1.618/1] bg-bg-elevated rounded-lg mb-3 overflow-hidden border border-border"
                            >
                              <img
                                v-if="getFirstImageUrl(plant.facit_images)"
                                :src="getFirstImageUrl(plant.facit_images)!"
                                :alt="plant.facit_name"
                                class="w-full h-full object-cover hover:scale-105 transition-transform duration-200"
                                loading="lazy"
                              />
                              <div v-else class="w-full h-full grid place-items-center">
                                <UIcon name="f7:tree" size="32" class="text-t-muted opacity-70" />
                              </div>
                            </ULink>

                            <!-- Plant content -->
                            <!-- Plant name -->

                            <!-- Plant attributes with badges -->
                            <div class="flex gap-2 justify-between items-start">
                              <div class="flex-1">
                                <div class="mb-2">
                                  <div class="">
                                    <ULink
                                      :to="`/vaxt/${plant.facit_id}/${encodeURIComponent(
                                        plant.facit_name
                                      )}`"
                                      class="text-t-regular hover:underline"
                                    >
                                      <h3 class="font-semibold text-base leading-tight">
                                        {{ plant.facit_name }}
                                      </h3>
                                    </ULink>
                                  </div>
                                  <p v-if="plant.facit_sv_name" class="text-md text-t-toned">
                                    {{ plant.facit_sv_name }}
                                  </p>
                                  <p
                                    v-if="
                                      plant.facit_name &&
                                      plant.name_by_plantskola !== plant.facit_name
                                    "
                                    class="text-xs text-t-muted italic"
                                  >
                                    ({{ plant.name_by_plantskola }})
                                  </p>
                                </div>
                                <div
                                  class="flex flex-wrap gap-1"
                                  v-if="plant.pot || plant.height || plant.own_columns"
                                >
                                  <UBadge
                                    v-if="plant.pot"
                                    color="neutral"
                                    variant="soft"
                                    class="text-xs"
                                  >
                                    {{ plant.pot }}
                                  </UBadge>
                                  <UBadge
                                    v-if="plant.height"
                                    color="neutral"
                                    variant="soft"
                                    class="text-xs"
                                  >
                                    {{ plant.height }}
                                  </UBadge>
                                  <!-- Custom fields from plantskola -->
                                  <div
                                    v-if="formatCustomFields(plant.own_columns).length > 0"
                                    class="flex flex-wrap gap-1"
                                  >
                                    <UBadge
                                      v-for="field in formatCustomFields(plant.own_columns)"
                                      :key="field.key"
                                      color="primary"
                                      variant="soft"
                                      class="text-xs"
                                    >
                                      {{ field.displayKey }}: {{ field.value }}
                                    </UBadge>
                                  </div>
                                </div>

                                <!-- Comment -->
                                <p
                                  v-if="plant.comment_by_plantskola"
                                  class="text-sm text-t-muted italic line-clamp-3 mt-1"
                                >
                                  {{ plant.comment_by_plantskola }}
                                </p>
                              </div>
                              <div class="" v-if="plant.price || plant.stock">
                                <div class="flex flex-col items-end gap-1">
                                  <span v-if="plant.price" class="font-bold text-base leading-none">
                                    {{ formatPrice(plant.price) }}
                                  </span>
                                  <span v-if="plant.stock" class="text-t-toned text-sm">
                                    {{ plant.stock }} st
                                  </span>
                                </div>
                              </div>
                            </div>

                            <!-- Price and stock info at bottom -->
                          </div>
                        </div>
                        <!-- Empty space for layout consistency -->
                        <div v-else class="w-full"></div>
                      </div>
                    </div>
                  </div>
                </DynamicScrollerItem>
              </DynamicScroller>
            </div>
          </div>
        </div>
      </section>
    </div>
  </div>
</template>

<style scoped>
/* Virtual scroller styles for DynamicScroller */
.scroller {
  height: 100%;
}

.scroller .vue-recycle-scroller__item-wrapper {
  box-sizing: border-box;
}

.scroller .vue-recycle-scroller__item-view {
  display: flex;
  flex-direction: column;
}

/* Dynamic scroller item styles */
.scroller .vue-recycle-scroller__item-view .vue-recycle-scroller__item-wrapper {
  overflow: hidden;
}

/* Line clamp utility for comments */
.line-clamp-2 {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.line-clamp-3 {
  display: -webkit-box;
  -webkit-line-clamp: 3;
  line-clamp: 3;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

/* Optimize transitions for virtual scrolling */
.scroller .vue-recycle-scroller {
  position: relative;
}

.scroller .vue-recycle-scroller.direction-vertical:not(.page-mode) {
  overflow-y: auto;
}

.scroller .vue-recycle-scroller__slot {
  flex: none;
}

/* Optimize virtual scrolling performance for Chromium */
@supports (-webkit-appearance: none) and (not (-moz-appearance: none)) {
  .scroller {
    contain: layout style paint;
    will-change: scroll-position;
  }

  /* Better rendering for dynamic content */
  .vue-recycle-scroller__item-view {
    transform: translateZ(0);
    backface-visibility: hidden;
  }
}

/* Custom scrollbar styling */
.scroller::-webkit-scrollbar {
  width: 8px;
}

.scroller::-webkit-scrollbar-track {
  background: transparent;
}

.scroller::-webkit-scrollbar-thumb {
  background: var(--ui-text-muted);
  border-radius: 4px;
  opacity: 0.5;
}

.scroller::-webkit-scrollbar-thumb:hover {
  opacity: 0.8;
}

/* Firefox scrollbar */
.scroller {
  scrollbar-width: thin;
  scrollbar-color: var(--ui-text-muted) transparent;
}
</style>
