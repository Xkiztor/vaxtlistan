<!-- Superadmin page for managing and viewing all plants in the facit table -->
<script setup lang="ts">
// SEO metadata for superadmin vaxter page
useHead({
  title: 'Växter - Superadmin - Växtlistan',
  meta: [
    {
      name: 'robots',
      content: 'noindex, nofollow', // Admin pages should not be indexed
    },
  ],
});

import type { Facit } from '~/types/supabase-tables';

// Simplified type for the plant data we're fetching in the table
interface PlantTableData {
  id: number;
  name: string;
  sv_name?: string | null;
  is_synonym?: boolean | null;
  popularity_score?: number | null;
  user_submitted?: boolean | null;
}

// Set the layout for this page
definePageMeta({
  layout: 'superadmin',
  middleware: 'superadmin',
});

// Supabase client and reactive state
const supabase = useSupabaseClient();
const toast = useToast();

// Pagination and search state
const page = ref(1);
const pageSize = 50;
const totalPlants = ref(0);
const searchQuery = ref('');
const loading = ref(false);

// Plant data
const plants = ref<PlantTableData[]>([]);

// Modal state for showing full plant details
const isModalOpen = ref(false);
const selectedPlant = ref<Facit | null>(null);
const loadingPlantDetails = ref(false);

// Analytics modal state
const isAnalyticsModalOpen = ref(false);
const selectedPlantAnalytics = ref<{ id: number; name: string } | null>(null);
const analyticsData = ref<{ view_date: string; view_count: number }[]>([]);
const loadingAnalytics = ref(false);

// Popularity update state
const updatingPopularity = ref(false);

// Search input with debouncing
const debouncedSearchQuery = refDebounced(searchQuery, 300);

// Fetch plants with pagination and search
const {
  data: plantsData,
  status,
  error,
  refresh,
} = await useAsyncData(
  'superadmin-plants',
  async () => {
    loading.value = true;

    try {
      // Base query for counting total results
      let countQuery = supabase.from('facit').select('*', { count: 'exact', head: true });

      // Base query for fetching data
      let dataQuery = supabase
        .from('facit')
        .select(
          `
          id,
          name,
          sv_name,
          is_synonym,
          popularity_score,
          user_submitted
        `
        )
        .order('popularity_score', { ascending: false, nullsFirst: false })
        .order('name', { ascending: true })
        .range((page.value - 1) * pageSize, page.value * pageSize - 1);

      // Apply search filter if query exists
      if (debouncedSearchQuery.value.trim()) {
        const searchTerm = debouncedSearchQuery.value.trim();

        // Check if search term is a number (for ID search)
        const isNumericSearch = /^\d+$/.test(searchTerm);

        let searchFilter: string;
        if (isNumericSearch) {
          // Search by ID and names
          searchFilter = `id.eq.${searchTerm},name.ilike.%${searchTerm}%,sv_name.ilike.%${searchTerm}%`;
        } else {
          // Search only by names
          searchFilter = `name.ilike.%${searchTerm}%,sv_name.ilike.%${searchTerm}%`;
        }

        countQuery = countQuery.or(searchFilter);
        dataQuery = dataQuery.or(searchFilter);
      }

      // Execute both queries
      const [countResult, dataResult] = await Promise.all([countQuery, dataQuery]);

      if (countResult.error) throw countResult.error;
      if (dataResult.error) throw dataResult.error;

      totalPlants.value = countResult.count || 0;
      plants.value = dataResult.data || [];

      return {
        plants: dataResult.data || [],
        total: countResult.count || 0,
      };
    } catch (err) {
      console.error('Error fetching plants:', err);
      toast.add({
        title: 'Fel',
        description: 'Kunde inte hämta växtdata',
        color: 'error',
      });
      return { plants: [], total: 0 };
    } finally {
      loading.value = false;
    }
  },
  {
    watch: [page, debouncedSearchQuery],
    server: false,
    lazy: true,
  }
);

// Calculate pagination info
const totalPages = computed(() => Math.ceil(totalPlants.value / pageSize));
const startItem = computed(() => (page.value - 1) * pageSize + 1);
const endItem = computed(() => Math.min(page.value * pageSize, totalPlants.value));

// Handle page change
const handlePageChange = (newPage: number) => {
  page.value = newPage;
  refresh();
};

// Handle search clear
const clearSearch = () => {
  searchQuery.value = '';
};

// Fetch full plant details for modal
const showPlantDetails = async (plantId: number) => {
  loadingPlantDetails.value = true;
  try {
    const { data, error } = await supabase.from('facit').select('*').eq('id', plantId).single();

    if (error) throw error;

    selectedPlant.value = data;
    isModalOpen.value = true;
  } catch (err) {
    console.error('Error fetching plant details:', err);
    toast.add({
      title: 'Fel',
      description: 'Kunde inte hämta växtdetaljer',
      color: 'error',
    });
  } finally {
    loadingPlantDetails.value = false;
  }
};

// Close modal
const closeModal = () => {
  isModalOpen.value = false;
  selectedPlant.value = null;
};

// Show plant analytics modal
const showPlantAnalytics = async (plantId: number, plantName: string) => {
  loadingAnalytics.value = true;
  selectedPlantAnalytics.value = { id: plantId, name: plantName };

  try {
    // Fetch analytics data for the last 365 days
    const { data, error } = await supabase
      .from('plant_analytics')
      .select('view_date, view_count')
      .eq('facit_id', plantId)
      .gte(
        'view_date',
        new Date(Date.now() - 365 * 24 * 60 * 60 * 1000).toISOString().split('T')[0]
      )
      .order('view_date', { ascending: true });

    if (error) throw error;

    analyticsData.value = data || [];
    isAnalyticsModalOpen.value = true;
  } catch (err) {
    console.error('Error fetching plant analytics:', err);
    toast.add({
      title: 'Fel',
      description: 'Kunde inte hämta analytikdata',
      color: 'error',
    });
  } finally {
    loadingAnalytics.value = false;
  }
};

// Close analytics modal
const closeAnalyticsModal = () => {
  isAnalyticsModalOpen.value = false;
  selectedPlantAnalytics.value = null;
  analyticsData.value = [];
};

// Computed properties for chart data
const chartData = computed(() => {
  if (!analyticsData.value.length) return [];

  return analyticsData.value.map((day) => ({
    date: day.view_date,
    views: day.view_count,
    dateFormatted: new Date(day.view_date).toLocaleDateString('sv-SE', {
      month: 'short',
      day: 'numeric',
    }),
  }));
});

const chartCategories = {
  views: {
    name: 'Visningar',
    color: '#10b981', // Success green color
  },
};

const xFormatter = (i: number) => chartData.value[i]?.dateFormatted || '';

// Format field values for display
const formatFieldValue = (value: any): string => {
  if (value === null || value === undefined) return '—';
  if (Array.isArray(value)) {
    if (value.length === 0) return '—';
    return value.map((v) => String(v)).join(', ');
  }
  if (typeof value === 'boolean') return value ? 'Ja' : 'Nej';
  if (typeof value === 'object') return JSON.stringify(value, null, 2);
  return String(value);
};

// Update plant popularity scores
const updatePopularityScores = async () => {
  updatingPopularity.value = true;
  try {
    const { data, error } = await supabase.rpc('update_plant_popularity_scores');

    if (error) throw error;

    // Refresh the current page data to show updated popularity scores
    await refresh();

    const result = data as Array<{ updated_count: number; execution_time_ms: number }>;
    const updatedCount = result?.[0]?.updated_count || 0;
    const executionTime = Math.round(result?.[0]?.execution_time_ms || 0);

    toast.add({
      title: 'Popularitetspoäng uppdaterade',
      description: `${updatedCount} växter uppdaterades på ${executionTime}ms`,
      color: 'success',
    });
  } catch (err) {
    console.error('Error updating popularity scores:', err);
    toast.add({
      title: 'Fel',
      description: 'Kunde inte uppdatera popularitetspoäng',
      color: 'error',
    });
  } finally {
    updatingPopularity.value = false;
  }
};
</script>

<template>
  <div class="container mx-auto p-6 max-w-7xl">
    <!-- Page header -->
    <div class="mb-8">
      <div class="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 mb-4">
        <div>
          <h1 class="text-3xl font-bold text-t-regular mb-2">Växtdatabas</h1>
          <p class="text-t-toned">
            Hantera och visa alla växter i facit-tabellen ({{ totalPlants.toLocaleString('sv-SE') }}
            växter totalt)
          </p>
        </div>

        <UButton
          @click="updatePopularityScores"
          :loading="updatingPopularity"
          color="primary"
          variant="solid"
          icon="i-heroicons-arrow-path"
          size="sm"
        >
          Uppdatera popularitet
        </UButton>
      </div>
    </div>

    <!-- Search and filters -->
    <div class="mb-6 flex flex-col sm:flex-row gap-4 items-start sm:items-center justify-between">
      <div class="flex-1 max-w-md">
        <UInput
          v-model="searchQuery"
          placeholder="Sök växter... (namn eller ID)"
          icon="i-heroicons-magnifying-glass"
          size="lg"
          :loading="status === 'pending'"
        >
          <template #trailing>
            <UButton
              v-if="searchQuery"
              variant="link"
              icon="i-heroicons-x-mark"
              @click="clearSearch"
              size="xs"
              color="neutral"
            />
          </template>
        </UInput>
      </div>

      <div class="text-sm text-t-toned">
        Visar {{ startItem }}-{{ endItem }} av {{ totalPlants.toLocaleString('sv-SE') }} växter
      </div>
    </div>

    <!-- Loading state -->
    <div v-if="status === 'pending' && !plants.length" class="flex justify-center py-12">
      <UIcon name="i-heroicons-arrow-path" class="animate-spin text-2xl text-t-toned" />
    </div>

    <!-- Error state -->
    <UAlert
      v-else-if="error"
      color="error"
      variant="soft"
      title="Fel vid hämtning av data"
      :description="error.message"
      class="mb-6"
    />

    <!-- Plants table -->
    <div v-else class="bg-bg-elevated rounded-xl border border-border overflow-hidden">
      <div class="overflow-x-auto">
        <table class="w-full">
          <thead class="bg-bg-top border-b border-border">
            <tr>
              <th class="px-4 py-3 text-left text-sm font-semibold text-t-regular">ID</th>
              <th class="px-4 py-3 text-left text-sm font-semibold text-t-regular">
                Vetenskapligt namn
              </th>
              <th class="px-4 py-3 text-left text-sm font-semibold text-t-regular">Svenskt namn</th>
              <th class="px-4 py-3 text-left text-sm font-semibold text-t-regular">Status</th>
              <th class="px-4 py-3 text-left text-sm font-semibold text-t-regular">Popularitet</th>
              <th class="px-4 py-3 text-left text-sm font-semibold text-t-regular"></th>
            </tr>
          </thead>
          <tbody class="divide-y divide-border">
            <tr v-for="plant in plants" :key="plant.id" class="hover:bg-bg-top transition-colors">
              <!-- ID -->
              <td class="px-4 py-3">
                <span class="text-sm font-mono text-t-toned">#{{ plant.id }}</span>
              </td>

              <!-- Scientific name -->
              <td class="px-4 py-3">
                <div class="font-medium text-t-regular italic">{{ plant.name }}</div>
              </td>

              <!-- Swedish name -->
              <td class="px-4 py-3">
                <div class="text-t-regular">{{ plant.sv_name || '—' }}</div>
              </td>

              <!-- Status badges -->
              <td class="px-4 py-3">
                <div class="flex flex-wrap gap-1">
                  <UBadge
                    v-if="plant.is_synonym"
                    label="Synonym"
                    color="warning"
                    variant="soft"
                    size="xs"
                  />
                  <UBadge
                    v-if="plant.user_submitted"
                    label="Användarskickad"
                    color="info"
                    variant="soft"
                    size="xs"
                  />
                </div>
              </td>

              <!-- Popularity score -->
              <td class="px-4 py-3">
                <div class="text-sm text-t-regular">
                  {{ plant.popularity_score ? Math.round(plant.popularity_score) : '—' }}
                </div>
              </td>

              <!-- Actions -->
              <td class="px-4 py-3">
                <div class="flex gap-2">
                  <UButton
                    :to="`/vaxt/${plant.id}/${plant.name
                      .toLowerCase()
                      .replace(/[^a-z0-9]+/g, '-')
                      .replace(/^-|-$/g, '')}`"
                    target="_blank"
                    size="xs"
                    variant="outline"
                    color="primary"
                    icon="i-heroicons-arrow-top-right-on-square"
                  >
                  </UButton>
                  <UButton
                    @click="showPlantAnalytics(plant.id, plant.name)"
                    :loading="loadingAnalytics"
                    size="xs"
                    variant="outline"
                    color="success"
                    icon="material-symbols:bar-chart-4-bars-rounded"
                  >
                  </UButton>
                  <UButton
                    @click="showPlantDetails(plant.id)"
                    :loading="loadingPlantDetails"
                    size="xs"
                    variant="outline"
                    color="primary"
                    icon="material-symbols:list-alt-outline-rounded"
                  >
                  </UButton>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Empty state -->
      <div v-if="status !== 'pending' && plants.length === 0" class="text-center py-12">
        <UIcon name="i-heroicons-magnifying-glass" class="text-4xl text-t-muted mb-4" />
        <h3 class="text-lg font-semibold text-t-regular mb-2">Inga växter hittades</h3>
        <p class="text-t-toned">
          {{
            searchQuery
              ? 'Prova att ändra dina söktermer'
              : 'Inga växter tillgängliga för tillfället'
          }}
        </p>
      </div>
    </div>

    <!-- Pagination -->
    <div v-if="totalPages > 1" class="mt-6 flex justify-center">
      <UPagination
        v-model:page="page"
        :items-per-page="pageSize"
        :total="totalPlants"
        :max="7"
        show-last
        show-first
        show-edges
        size="sm"
      />
    </div>

    <!-- Plant Details Modal -->
    <UModal v-model:open="isModalOpen" prevent-close>
      <template #content>
        <div class="p-6">
          <!-- Modal Header -->
          <div class="flex items-center justify-between mb-6">
            <div>
              <h3 class="text-lg font-semibold text-t-regular">Växtdetaljer</h3>
              <p v-if="selectedPlant" class="text-sm text-t-toned italic">
                {{ selectedPlant.name }}
              </p>
            </div>
            <UButton
              @click="closeModal"
              variant="ghost"
              icon="i-heroicons-x-mark"
              size="sm"
              color="neutral"
            />
          </div>
          <!-- Loading state -->
          <div v-if="loadingPlantDetails" class="flex justify-center py-8">
            <UIcon name="i-heroicons-arrow-path" class="animate-spin text-xl text-t-toned" />
          </div>
          <!-- Plant Details -->
          <div v-else-if="selectedPlant" class="space-y-4 max-h-96 overflow-y-auto">
            <div
              v-for="[key, value] in Object.entries(selectedPlant)"
              :key="key"
              class="grid grid-cols-1 md:grid-cols-3 gap-2 p-3 bg-bg-top rounded-lg"
            >
              <div class="font-medium text-t-regular">
                {{ key }}
              </div>
              <div class="md:col-span-2 text-t-toned text-sm break-words">
                <pre
                  v-if="typeof value === 'object' && value !== null"
                  class="whitespace-pre-wrap text-xs"
                  >{{ formatFieldValue(value) }}</pre
                >
                <span v-else>{{ formatFieldValue(value) }}</span>
              </div>
            </div>
          </div>
          <!-- Modal Footer -->
          <div class="flex justify-end mt-6 pt-4 border-t border-border">
            <UButton @click="closeModal" variant="outline"> Stäng </UButton>
          </div>
        </div>
      </template>
    </UModal>

    <!-- Plant Analytics Modal -->
    <UModal v-model:open="isAnalyticsModalOpen" prevent-close fullscreen>
      <template #content>
        <div class="h-full flex flex-col">
          <!-- Modal Header -->
          <div class="flex items-center justify-between p-6 border-b border-border bg-bg-elevated">
            <div>
              <h3 class="text-xl font-semibold text-t-regular">Visningsstatistik</h3>
              <p v-if="selectedPlantAnalytics" class="text-sm text-t-toned italic">
                {{ selectedPlantAnalytics.name }} (ID: {{ selectedPlantAnalytics.id }})
              </p>
            </div>
            <UButton
              @click="closeAnalyticsModal"
              variant="outline"
              icon="i-heroicons-x-mark"
              size="xl"
              color="neutral"
            />
          </div>

          <!-- Content -->
          <div class="flex-1 p-6 overflow-auto">
            <!-- Loading state -->
            <div v-if="loadingAnalytics" class="flex justify-center py-12">
              <UIcon name="i-heroicons-arrow-path" class="animate-spin text-2xl text-t-toned" />
            </div>

            <!-- Analytics content -->
            <div v-else-if="analyticsData.length > 0" class="space-y-6">
              <!-- Summary stats -->
              <div class="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-8">
                <div class="bg-bg-top rounded-xl p-4 border border-border">
                  <div class="text-sm text-t-toned mb-1">Totala visningar</div>
                  <div class="text-2xl font-bold text-t-regular">
                    {{
                      analyticsData
                        .reduce((sum, day) => sum + day.view_count, 0)
                        .toLocaleString('sv-SE')
                    }}
                  </div>
                </div>
                <div class="bg-bg-top rounded-xl p-4 border border-border">
                  <div class="text-sm text-t-toned mb-1">Dagar med visningar</div>
                  <div class="text-2xl font-bold text-t-regular">
                    {{ analyticsData.length.toLocaleString('sv-SE') }}
                  </div>
                </div>
                <div class="bg-bg-top rounded-xl p-4 border border-border">
                  <div class="text-sm text-t-toned mb-1">Snitt per dag</div>
                  <div class="text-2xl font-bold text-t-regular">
                    {{
                      Math.round(
                        analyticsData.reduce((sum, day) => sum + day.view_count, 0) /
                          analyticsData.length
                      ).toLocaleString('sv-SE')
                    }}
                  </div>
                </div>
              </div>

              <!-- Chart container -->
              <div
                class="bg-bg-top rounded-xl p-6 border border-border"
                v-if="analyticsData.length > 1"
              >
                <h4 class="text-lg font-semibold text-t-regular mb-4">Visningar över tid</h4>
                <div class="h-96">
                  <LineChart
                    :data="chartData"
                    :categories="chartCategories"
                    :height="300"
                    :xFormatter="xFormatter"
                    xLabel="Datum"
                    yLabel="Antal visningar"
                  />
                </div>
              </div>

              <!-- Data table -->
              <div class="bg-bg-top rounded-xl border border-border overflow-hidden">
                <div class="px-6 py-4 border-b border-border">
                  <h4 class="text-lg font-semibold text-t-regular">Detaljerad data</h4>
                </div>
                <div class="max-h-64 overflow-y-auto">
                  <table class="w-full">
                    <thead class="bg-bg-elevated border-b border-border sticky top-0">
                      <tr>
                        <th class="px-4 py-3 text-left text-sm font-semibold text-t-regular">
                          Datum
                        </th>
                        <th class="px-4 py-3 text-left text-sm font-semibold text-t-regular">
                          Visningar
                        </th>
                      </tr>
                    </thead>
                    <tbody class="divide-y divide-border">
                      <tr v-for="day in analyticsData.slice().reverse()" :key="day.view_date">
                        <td class="px-4 py-3 text-sm text-t-regular">
                          {{ new Date(day.view_date).toLocaleDateString('sv-SE') }}
                        </td>
                        <td class="px-4 py-3 text-sm text-t-regular font-mono">
                          {{ day.view_count.toLocaleString('sv-SE') }}
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </div>
              </div>
            </div>

            <!-- No data state -->
            <div v-else class="text-center py-12">
              <UIcon name="i-heroicons-chart-bar" class="text-4xl text-t-muted mb-4" />
              <h3 class="text-lg font-semibold text-t-regular mb-2">Ingen analytikdata</h3>
              <p class="text-t-toned">
                Inga visningar har registrerats för denna växt under de senaste 365 dagarna.
              </p>
            </div>
          </div>
        </div>
      </template>
    </UModal>
  </div>
</template>
