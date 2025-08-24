<script setup lang="ts">
// SEO metadata for plantskola lager admin page
useHead({
  title: 'Lagerhantering - Admin - Växtlistan',
  meta: [
    {
      name: 'description',
      content:
        'Hantera ditt växtlager på Växtlistan. Uppdatera lagersaldo, priser och tillgänglighet för dina växter.',
    },
    {
      name: 'robots',
      content: 'noindex, nofollow', // Admin pages should not be indexed
    },
  ],
});

definePageMeta({
  layout: 'admin',
  middleware: 'plantskola-admin',
});
// --- Types ---
import type { Totallager, Facit, Plantskola, LagerComplete } from '~/types/supabase-tables';
import { RecycleScroller, DynamicScroller, DynamicScrollerItem } from 'vue-virtual-scroller';
import 'vue-virtual-scroller/dist/vue-virtual-scroller.css';

// --- State ---
const user = useSupabaseUser();
const supabase = useSupabaseClient();
const router = useRouter();

// --- Composables ---
import { usePlantType } from '~/composables/usePlantType';
import { useLagerStore } from '~/stores/lager';

const { isMobile } = useScreen();
const { width, height } = useWindowSize();

// Scroll shadow state for scrollers
const actionsScrollerRef = ref<HTMLElement>();
const filtersScrollerRef = ref<HTMLElement>();
const actionsScrollState = reactive({
  canScrollLeft: false,
  canScrollRight: false,
});
const filtersScrollState = reactive({
  canScrollLeft: false,
  canScrollRight: false,
});

// Function to check scroll state
const checkScrollState = (element: HTMLElement, state: typeof actionsScrollState) => {
  const { scrollLeft, scrollWidth, clientWidth } = element;
  state.canScrollLeft = scrollLeft > 0;
  state.canScrollRight = scrollLeft < scrollWidth - clientWidth - 1;
};

// Initialize scroll state on mount
onMounted(() => {
  nextTick(() => {
    if (actionsScrollerRef.value) {
      checkScrollState(actionsScrollerRef.value, actionsScrollState);
      actionsScrollerRef.value.addEventListener('scroll', () => {
        checkScrollState(actionsScrollerRef.value!, actionsScrollState);
      });
    }
    if (filtersScrollerRef.value) {
      checkScrollState(filtersScrollerRef.value, filtersScrollState);
      filtersScrollerRef.value.addEventListener('scroll', () => {
        checkScrollState(filtersScrollerRef.value!, filtersScrollState);
      });
    }
  });
});

// Watch for window resize to update scroll state
watch(width, () => {
  nextTick(() => {
    if (actionsScrollerRef.value) checkScrollState(actionsScrollerRef.value, actionsScrollState);
    if (filtersScrollerRef.value) checkScrollState(filtersScrollerRef.value, filtersScrollState);
  });
});

// Search/filter state
const search = ref('');
const filterType = ref<any>('');
const types = [
  { value: 13, label: 'Träd' },
  { value: 1, label: 'Perenner' },
  { value: 2, label: 'Klätterväxter' },
  { value: 5, label: 'Ormbunke' },
  { value: 19, label: 'Barrträd' },
  { value: 9, label: 'Rosor' },
];

// Sorting state
const sortBy = ref<'name-asc' | 'name-desc' | 'price-asc' | 'price-desc' | 'stock' | 'height'>(
  'name-asc'
);
const sortOptions = [
  { value: 'name-asc', label: 'Namn A-Z' },
  { value: 'name-desc', label: 'Namn Z-A' },
  { value: 'price-asc', label: 'Billigast först' },
  { value: 'price-desc', label: 'Dyrast först' },
  { value: 'stock', label: 'Lager' },
  { value: 'height', label: 'Höjd' },
];

// Advanced filters modal state
const showAdvancedFilters = ref(false);
const advancedFilters = reactive({
  minPrice: null as number | null,
  maxPrice: null as number | null,
  minStock: null as number | null,
  maxStock: null as number | null,
  pot: '',
  height: '',
  hasComment: 'all' as 'all' | 'with' | 'without', // all = all, with = with comment, without = without comment
});

// Comment filter options
const commentFilterOptions = [
  { value: 'all', label: 'Alla' },
  { value: 'with', label: 'Med kommentar' },
  { value: 'without', label: 'Utan kommentar' },
];

const showAddModal = ref(false);
const showEditModal = ref(false);
const editPlant = ref<LagerComplete | null>(null);

// Virtual scroller configuration
const dynamicScrollerRef = ref<InstanceType<typeof DynamicScroller>>();
const virtualScrollerHeight = ref(600); // Default height

// Calculate dynamic height based on available space
const calculateScrollerHeight = () => {
  if (process.client) {
    const viewport = height.value;
    var navbarHeight = 80; // Approximate height of navbar
    var headerHeight = 100; // Approximate height of header, actions, filters
    var bottomPadding = 0; // Bottom padding for scroller
    var borderSpace = 0;

    if (width.value > 768) {
      // Mobile view
      navbarHeight = 80; // Adjust for mobile navbar height
      headerHeight = 128; // Adjust for mobile header height
      bottomPadding = 32; // Add some padding for mobile
      borderSpace = 2; // Add border space for mobile
    }
    virtualScrollerHeight.value =
      viewport - headerHeight - navbarHeight - bottomPadding - borderSpace;
  }
};

// Reset scroll position when filters change
watch(
  [search, filterType, sortBy, advancedFilters],
  () => {
    // Reset scroll position when filters change
    if (dynamicScrollerRef.value && 'scrollToTop' in dynamicScrollerRef.value) {
      (dynamicScrollerRef.value as any).scrollToTop();
    }
  },
  { deep: true }
);

// Update scroller height on mount and resize
onMounted(() => {
  calculateScrollerHeight();
  window.addEventListener('resize', calculateScrollerHeight);
});

onUnmounted(() => {
  window.removeEventListener('resize', calculateScrollerHeight);
});

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

// --- Fetch lager with complete data using SQL function ---
const { data: lagerComplete, refresh: refreshLager } = await useAsyncData(
  'lager-complete',
  async () => {
    console.log('Fetching lager');

    if (!plantskola.value) return [];

    // Use the SQL function to get complete lager data with facit information
    const { data, error } = await supabase.rpc('get_plantskola_lager_complete', {
      p_plantskola_id: plantskola.value.id,
    } as any); // Type assertion to handle Supabase RPC parameter typing

    if (error || !data) return [];
    return data as LagerComplete[];
  },
  {
    lazy: true,
  }
);

// Watch for data changes to update scroll state
watch(lagerComplete, () => {
  nextTick(() => {
    if (actionsScrollerRef.value) checkScrollState(actionsScrollerRef.value, actionsScrollState);
    if (filtersScrollerRef.value) checkScrollState(filtersScrollerRef.value, filtersScrollState);
  });
});

// --- Computed filtered and sorted list ---
const filteredLager = computed(() => {
  if (!lagerComplete.value) return [];
  let result = lagerComplete.value;

  // Text search filter
  if (search.value) {
    const s = search.value.toLowerCase();
    result = result.filter(
      (p) =>
        p.name_by_plantskola?.toLowerCase().includes(s) ||
        p.facit_sv_name?.toLowerCase().includes(s) ||
        p.facit_name?.toLowerCase().includes(s)
    );
  }

  // Plant type filter
  if (filterType.value) {
    result = result.filter((p) => {
      return p.facit_rhs_types?.includes(Number(filterType.value));
    });
  }
  // Advanced filters
  if (advancedFilters.minPrice !== null) {
    result = result.filter(
      (p) => p.price !== null && p.price !== undefined && p.price >= advancedFilters.minPrice!
    );
  }
  if (advancedFilters.maxPrice !== null) {
    result = result.filter(
      (p) => p.price !== null && p.price !== undefined && p.price <= advancedFilters.maxPrice!
    );
  }
  if (advancedFilters.minStock !== null) {
    result = result.filter(
      (p) => p.stock !== null && p.stock !== undefined && p.stock >= advancedFilters.minStock!
    );
  }
  if (advancedFilters.maxStock !== null) {
    result = result.filter(
      (p) => p.stock !== null && p.stock !== undefined && p.stock <= advancedFilters.maxStock!
    );
  }
  if (advancedFilters.pot) {
    result = result.filter((p) => p.pot?.toLowerCase().includes(advancedFilters.pot.toLowerCase()));
  }
  if (advancedFilters.height) {
    result = result.filter((p) =>
      p.height?.toLowerCase().includes(advancedFilters.height.toLowerCase())
    );
  }
  if (advancedFilters.hasComment !== 'all') {
    if (advancedFilters.hasComment === 'with') {
      result = result.filter(
        (p) => p.comment_by_plantskola && p.comment_by_plantskola.trim() !== ''
      );
    } else if (advancedFilters.hasComment === 'without') {
      result = result.filter(
        (p) => !p.comment_by_plantskola || p.comment_by_plantskola.trim() === ''
      );
    }
  }

  // Sorting
  result.sort((a, b) => {
    let aValue: any, bValue: any;

    switch (sortBy.value) {
      case 'name-asc':
        aValue = a.facit_name || a.name_by_plantskola || '';
        bValue = b.facit_name || b.name_by_plantskola || '';
        return aValue.localeCompare(bValue, 'sv');
      case 'name-desc':
        aValue = a.facit_name || a.name_by_plantskola || '';
        bValue = b.facit_name || b.name_by_plantskola || '';
        return bValue.localeCompare(aValue, 'sv');
      case 'price-asc':
        aValue = a.price || 0;
        bValue = b.price || 0;
        return aValue - bValue;
      case 'price-desc':
        aValue = a.price || 0;
        bValue = b.price || 0;
        return bValue - aValue;
      case 'stock':
        aValue = a.stock || 0;
        bValue = b.stock || 0;
        return bValue - aValue;
      case 'height':
        aValue = parseFloat((a.height || '0').replace(/[^\d.-]/g, '')) || 0;
        bValue = parseFloat((b.height || '0').replace(/[^\d.-]/g, '')) || 0;
        return bValue - aValue;
      default:
        return 0;
    }
  });

  return result;
});

// Clear advanced filters function
const clearAdvancedFilters = () => {
  advancedFilters.minPrice = null;
  advancedFilters.maxPrice = null;
  advancedFilters.minStock = null;
  advancedFilters.maxStock = null;
  advancedFilters.pot = '';
  advancedFilters.height = '';
  advancedFilters.hasComment = 'all';
};

// Check if any advanced filters are active
const hasActiveAdvancedFilters = computed(() => {
  return (
    advancedFilters.minPrice !== null ||
    advancedFilters.maxPrice !== null ||
    advancedFilters.minStock !== null ||
    advancedFilters.maxStock !== null ||
    advancedFilters.pot !== '' ||
    advancedFilters.height !== '' ||
    advancedFilters.hasComment !== 'all'
  );
});

// --- Add new plant to lager (two-step modal) ---
const addPlantModalOpen = ref(false); // Modal open state
const addStep = ref<'pick' | 'form'>('pick'); // Step: 'pick' or 'form'
const prevStep = ref<'pick' | 'form'>('pick'); // Track previous step for direction
const newPlantFacitId = ref<number | null>(null); // Selected facit id
const addPlantLoading = ref(false); // Loading state for save
const addForm = reactive({
  name_by_plantskola: '',
  comment_by_plantskola: '',
  pot: '',
  height: '',
  price: null as number | null,
  stock: null as number | null,
});

// Slide direction for modal steps
const slideDirection = computed(() => {
  if (addStep.value === prevStep.value) return 'left'; // default
  return addStep.value === 'form' ? 'left' : 'right';
});

watch(addStep, (val, oldVal) => {
  prevStep.value = oldVal;
});

// Reset modal state
const resetAddModal = () => {
  addStep.value = 'pick';
  newPlantFacitId.value = null;
  addForm.name_by_plantskola = '';
  addForm.comment_by_plantskola = '';
  addForm.pot = '';
  addForm.height = '';
  addForm.price = null;
  addForm.stock = null;
};

// Open modal
const openAddModal = () => {
  resetAddModal();
  addPlantModalOpen.value = true;
};

// PlantPicker select handler
const onPlantPickerSelect = (facitId: number) => {
  newPlantFacitId.value = facitId;
  addStep.value = 'form';
};

// PlantPicker addSelect handler (for when a new plant is added to facit)
const onPlantPickerAddSelect = (facitId: number) => {
  newPlantFacitId.value = facitId;
  addStep.value = 'form';
};

// --- Export functionality ---
const showExportModal = ref(false);
const exportLoading = ref(false);
const exportOptions = reactive({
  format: 'csv',
  includeFields: {
    facit_name: true,
    facit_sv_name: true,
    name_by_plantskola: true,
    comment_by_plantskola: true,
    pot: true,
    height: true,
    price: true,
    stock: true,
    plant_type: true,
    hidden: false,
  },
  includeHidden: false,
  onlyFiltered: true,
});

const exportFormatOptions = [
  { value: 'csv', label: 'CSV (Excel)' },
  { value: 'json', label: 'JSON' },
  { value: 'txt', label: 'TXT (Tab-separerat)' },
];

type ExportFieldKey = keyof typeof exportOptions.includeFields;

const exportFieldOptions: Array<{ key: ExportFieldKey; label: string; enabled: boolean }> = [
  { key: 'facit_name', label: 'Vetenskapligt namn', enabled: true },
  { key: 'facit_sv_name', label: 'Svenskt namn', enabled: true },
  { key: 'comment_by_plantskola', label: 'Kommentar', enabled: true },
  { key: 'pot', label: 'Kruka', enabled: true },
  { key: 'height', label: 'Höjd', enabled: true },
  { key: 'price', label: 'Pris', enabled: true },
  { key: 'stock', label: 'Lager', enabled: true },
  { key: 'hidden', label: 'Dold status', enabled: false },
];

// Get data for export based on options
const getExportData = () => {
  let data = exportOptions.onlyFiltered ? filteredLager.value : lagerComplete.value || [];

  // Filter out hidden plants if not included
  if (!exportOptions.includeHidden) {
    data = data.filter((plant) => !plant.hidden);
  }

  return data.map((plant) => {
    const exportRow: any = {};

    if (exportOptions.includeFields.facit_name)
      exportRow['Vetenskapligt namn'] = plant.facit_name || '';
    if (exportOptions.includeFields.facit_sv_name)
      exportRow['Svenskt namn'] = plant.facit_sv_name || '';
    if (exportOptions.includeFields.comment_by_plantskola)
      exportRow['Kommentar'] = plant.comment_by_plantskola || '';
    if (exportOptions.includeFields.pot) exportRow['Kruka'] = plant.pot || '';
    if (exportOptions.includeFields.height) exportRow['Höjd'] = plant.height || '';
    if (exportOptions.includeFields.price) exportRow['Pris'] = plant.price || '';
    if (exportOptions.includeFields.stock) exportRow['Lager'] = plant.stock || '';
    if (exportOptions.includeFields.hidden) exportRow['Dold'] = plant.hidden ? 'Ja' : 'Nej';

    return exportRow;
  });
};

// Convert data to CSV format
const convertToCSV = (data: any[]) => {
  if (data.length === 0) return '';

  const headers = Object.keys(data[0]);
  const csvContent = [
    headers.join(','),
    ...data.map((row) =>
      headers
        .map((header) => {
          const value = row[header]?.toString() || '';
          // Escape quotes and wrap in quotes if contains comma or quote
          if (value.includes(',') || value.includes('"') || value.includes('\n')) {
            return `"${value.replace(/"/g, '""')}"`;
          }
          return value;
        })
        .join(',')
    ),
  ].join('\n');

  return csvContent;
};

// Convert data to tab-separated format
const convertToTSV = (data: any[]) => {
  if (data.length === 0) return '';

  const headers = Object.keys(data[0]);
  const tsvContent = [
    headers.join('\t'),
    ...data.map((row) =>
      headers.map((header) => (row[header]?.toString() || '').replace(/\t/g, ' ')).join('\t')
    ),
  ].join('\n');

  return tsvContent;
};

// Download file
const downloadFile = (content: string, filename: string, mimeType: string) => {
  const blob = new Blob([content], { type: mimeType });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  URL.revokeObjectURL(url);
};

// Export plants
const exportPlants = async () => {
  if (!plantskola.value) return;

  exportLoading.value = true;
  try {
    const data = getExportData();

    if (data.length === 0) {
      useToast().add({
        title: 'Ingen data',
        description: 'Det finns ingen data att exportera med valda inställningar.',
        color: 'warning',
      });
      return;
    }

    const timestamp = new Date().toISOString().split('T')[0];
    const plantskolaName = plantskola.value.name.replace(/[^a-zA-Z0-9]/g, '_');
    const filterSuffix =
      exportOptions.onlyFiltered &&
      (search.value || filterType.value || hasActiveAdvancedFilters.value)
        ? '_filtrerat'
        : '';

    let content: string;
    let filename: string;
    let mimeType: string;

    switch (exportOptions.format) {
      case 'csv':
        content = convertToCSV(data);
        filename = `lager_${plantskolaName}_${timestamp}${filterSuffix}.csv`;
        mimeType = 'text/csv;charset=utf-8';
        // Add BOM for proper UTF-8 handling in Excel
        content = '\uFEFF' + content;
        break;
      case 'json':
        content = JSON.stringify(data, null, 2);
        filename = `lager_${plantskolaName}_${timestamp}${filterSuffix}.json`;
        mimeType = 'application/json';
        break;
      case 'txt':
        content = convertToTSV(data);
        filename = `lager_${plantskolaName}_${timestamp}${filterSuffix}.txt`;
        mimeType = 'text/plain;charset=utf-8';
        break;
      default:
        throw new Error('Okänt exportformat');
    }

    downloadFile(content, filename, mimeType);

    useToast().add({
      title: 'Export klar',
      description: `${data.length} växter exporterade som ${exportOptions.format.toUpperCase()}`,
      color: 'primary',
    });

    showExportModal.value = false;
  } catch (e: any) {
    useToast().add({
      title: 'Exportfel',
      description: e.message || 'Kunde inte exportera data.',
      color: 'error',
    });
  } finally {
    exportLoading.value = false;
  }
};

// --- Delete all lager functionality ---
const showDeleteModal = ref(false);
const deleteLoading = ref(false);
const deleteOptions = reactive({
  deleteFiltered: false, // If true, delete only filtered plants; if false, delete all
  includeHidden: false, // Include hidden plants in deletion
});

// Reset delete confirmation when modal closes
watch(showDeleteModal, (isOpen) => {
  if (!isOpen) {
    deleteOptions.deleteFiltered = false;
    deleteOptions.includeHidden = false;
  }
});

// Get plants to delete based on options
const getPlantsToDelete = () => {
  let plantsToDelete = deleteOptions.deleteFiltered
    ? filteredLager.value
    : lagerComplete.value || [];

  // Filter out hidden plants if not included
  if (!deleteOptions.includeHidden) {
    plantsToDelete = plantsToDelete.filter((plant) => !plant.hidden);
  }

  return plantsToDelete;
};

// Get count of plants that would be deleted
const deleteCount = computed(() => {
  const plants = getPlantsToDelete();
  return plants.length;
});

// Delete multiple plants from lager
const deleteMultiplePlants = async () => {
  if (!plantskola.value) return;

  deleteLoading.value = true;
  try {
    const plantsToDelete = getPlantsToDelete();

    if (plantsToDelete.length === 0) {
      useToast().add({
        title: 'Ingen data',
        description: 'Det finns inga växter att radera med valda inställningar.',
        color: 'warning',
      });
      return;
    }

    // Delete plants in batches to avoid overwhelming the database
    const batchSize = 50;
    const plantIds = plantsToDelete.map((plant) => plant.id);

    for (let i = 0; i < plantIds.length; i += batchSize) {
      const batch = plantIds.slice(i, i + batchSize);
      const { error } = await supabase.from('totallager').delete().in('id', batch);

      if (error) throw new Error(error.message);
    }

    // Refresh the lager data
    await refreshLager();

    useToast().add({
      title: 'Raderingsoperation klar',
      description: `${plantsToDelete.length} växter raderade från lagret`,
      color: 'primary',
    });

    showDeleteModal.value = false;
  } catch (e: any) {
    useToast().add({
      title: 'Raderingsfel',
      description: e.message || 'Kunde inte radera växter.',
      color: 'error',
    });
  } finally {
    deleteLoading.value = false;
  }
};

// Handle updates from child components
const handlePlantUpdate = async () => {
  await refreshLager();
};
const addPlantToLager = async () => {
  if (!plantskola.value || !newPlantFacitId.value) return;

  addPlantLoading.value = true;
  try {
    const insertData = {
      facit_id: newPlantFacitId.value,
      plantskola_id: plantskola.value.id,
      name_by_plantskola: addForm.name_by_plantskola,
      comment_by_plantskola: addForm.comment_by_plantskola,
      pot: addForm.pot,
      height: addForm.height,
      price: addForm.price,
      stock: addForm.stock,
      hidden: false,
    };
    const { data, error } = await supabase
      .from('totallager')
      .insert(insertData as any)
      .select()
      .single();
    if (error) throw new Error(error.message);

    // Refresh the lager data
    await refreshLager();

    addPlantModalOpen.value = false;
    resetAddModal();
    useToast().add({ title: 'Växt tillagd', color: 'primary' });
  } catch (e: any) {
    useToast().add({
      title: 'Fel',
      description: e.message || 'Kunde inte lägga till växt.',
      color: 'error',
    });
  } finally {
    addPlantLoading.value = false;
  }
};
</script>

<template>
  <div class="max-xl:max-w-4xl mx-auto pt-8 md:px-4 md:pb-8 lager-page">
    <div class="flex flex-col md:flex-row md:items-end md:justify-between gap-4 mb-4 px-4">
      <div>
        <h1 class="text-3xl md:text-4xl font-black">Lager</h1>
        <div class="text-t-muted text-lg">
          Alla växter för {{ plantskola?.name || 'plantskola' }}
        </div>
      </div>
    </div>
    <div class="sticky top-20 z-10">
      <div class="bg-bg md:py-2">
        <!-- Actions scroller -->
        <div class="px-4 max-md:border-b max-md:border-t border-border relative">
          <!-- Left shadow -->
          <div
            v-show="actionsScrollState.canScrollLeft"
            class="absolute left-4 top-0 bottom-0 w-4 z-10 pointer-events-none bg-gradient-to-r from-bg to-transparent opacity-70"
          ></div>
          <!-- Right shadow -->
          <div
            v-show="actionsScrollState.canScrollRight"
            class="absolute right-4 top-0 bottom-0 w-8 z-10 pointer-events-none bg-gradient-to-l from-bg to-transparent"
          ></div>
          <div
            class="flex md:flex-row gap-2 md:gap-4 overflow-x-auto py-2 scroller-styles"
            ref="actionsScrollerRef"
          >
            <UButton
              color="neutral"
              :size="isMobile ? 'md' : 'xl'"
              icon="material-symbols:add"
              variant="subtle"
              class="md:w-auto min-w-max"
              :disabled="!plantskola"
              @click="openAddModal"
            >
              Lägg till växt
            </UButton>
            <UButton
              color="neutral"
              :size="isMobile ? 'md' : 'xl'"
              icon="uil:import"
              class="min-w-max md:w-auto"
              variant="subtle"
              to="/plantskola-admin/import"
              :disabled="!plantskola"
            >
              Importera
            </UButton>
            <UButton
              color="neutral"
              :size="isMobile ? 'md' : 'xl'"
              class="min-w-max md:w-auto"
              icon="uil:export"
              variant="subtle"
              :disabled="!plantskola || !lagerComplete || lagerComplete.length === 0"
              @click="showExportModal = true"
            >
              Exportera
            </UButton>
            <UButton
              color="neutral"
              :size="isMobile ? 'md' : 'xl'"
              class="min-w-max md:w-auto"
              variant="subtle"
              icon="material-symbols:delete-forever-outline-rounded"
              :disabled="!plantskola || !lagerComplete || lagerComplete.length === 0"
              @click="showDeleteModal = true"
            >
              Radera lager
            </UButton>
          </div>
        </div>
        <!-- Search and filter scroller -->
        <div class="px-4 max-md:border-b-2 border-border relative">
          <!-- Left shadow -->
          <div
            v-show="filtersScrollState.canScrollLeft"
            class="absolute left-4 top-0 bottom-0 w-4 z-10 pointer-events-none bg-gradient-to-r from-bg to-transparent"
          ></div>
          <!-- Right shadow -->
          <div
            v-show="filtersScrollState.canScrollRight"
            class="absolute right-4 top-0 bottom-0 w-8 z-10 pointer-events-none bg-gradient-to-l from-bg to-transparent"
          ></div>
          <div
            class="flex md:flex-row gap-2 md:gap-4 overflow-x-auto py-2 scroller-styles"
            ref="filtersScrollerRef"
          >
            <UInput
              v-model="search"
              placeholder="Sök"
              :size="isMobile ? 'md' : 'xl'"
              class="flex-1 min-w-40"
              icon="i-heroicons-magnifying-glass"
            >
              <template #trailing v-if="search">
                <UButton
                  variant="ghost"
                  color="neutral"
                  @click="search = ''"
                  icon="material-symbols:close-rounded"
                  size="xs"
                  class="p-1 opacity-60 hover:opacity-100"
                  aria-label="Rensa sökning"
                />
              </template>
            </UInput>
            <div class="flex flex-row items-center gap-1">
              <USelect
                v-model="filterType"
                :items="types"
                placeholder="Filtrera på typ"
                :size="isMobile ? 'md' : 'xl'"
                class="md:w-60 transition-all"
                :ui="{ item: 'cursor-pointer' }"
                value-attribute="value"
              />
              <UButton
                v-if="filterType"
                variant="outline"
                color="neutral"
                class=""
                @click="filterType = ''"
                icon="material-symbols:close-rounded"
                :size="isMobile ? 'md' : 'xl'"
              />
            </div>
            <div class="flex flex-row items-center gap-1">
              <USelect
                v-model="sortBy"
                :items="sortOptions"
                placeholder="Sortera"
                :size="isMobile ? 'md' : 'xl'"
                icon="material-symbols:sort-rounded"
                class="md:w-40 transition-all min-w-24"
                :ui="{ item: 'cursor-pointer' }"
                value-attribute="value"
              />
            </div>
            <UButton
              variant="subtle"
              color="neutral"
              class="min-w-max"
              @click="showAdvancedFilters = true"
              icon="material-symbols:filter-list"
              :size="isMobile ? 'md' : 'xl'"
            >
              Fler filter
              <UBadge v-if="hasActiveAdvancedFilters" size="xs" color="primary" class="ml-1">
                {{
                  (advancedFilters.minPrice !== null ? 1 : 0) +
                  (advancedFilters.maxPrice !== null ? 1 : 0) +
                  (advancedFilters.minStock !== null ? 1 : 0) +
                  (advancedFilters.maxStock !== null ? 1 : 0) +
                  (advancedFilters.pot !== '' ? 1 : 0) +
                  (advancedFilters.height !== '' ? 1 : 0) +
                  (advancedFilters.hasComment !== 'all' ? 1 : 0)
                }}
              </UBadge>
            </UButton>
          </div>
        </div>
      </div>
      <!-- Lager list with virtual scrolling -->
      <div v-if="!lagerComplete" class="flex justify-center py-12">
        <!-- <ULoader size="lg" color="primary" /> -->
        Laddar...
      </div>
      <div v-else-if="filteredLager.length === 0 && lagerComplete" class="py-8 text-center">
        <p class="text-lg font-bold">Inga växter matchade filtreringen</p>
      </div>
      <div v-else-if="filteredLager.length === 0" class="py-8 text-center">
        <p class="text-lg font-bold">Lägg till växter genom att till exempel:</p>
        <ul class="list-disc list-inside space-y-1">
          <li>
            <ULink to="/plantskola-admin/import" class="text-primary underline">Importera</ULink>
            från excel / google sheets
          </li>
          <li>
            Eller skicka eran lista till oss på mail så importerar vi den åt er
            <span class="block">ugo.linder@gmail.com</span>
          </li>
        </ul>
      </div>
      <div v-else class="md:border md:border-border md:rounded-lg md:mx-4 overflow-hidden">
        <!-- Virtual scroll container with dynamic sizing -->
        <!-- <RecycleScroller
          class="scroller max-md:pb-24"
          :items="filteredLager"
          :item-size="45"
          :style="{ height: virtualScrollerHeight + 'px' }"
          key-field="id"
          v-slot="{ item }"
          :buffer="2000"
        >
          <LagerListItem :plant="item" @update="handlePlantUpdate" class="px-2" />
        </RecycleScroller> -->
        <DynamicScroller
          ref="dynamicScrollerRef"
          class="scroller max-md:pb-24"
          :items="filteredLager"
          :min-item-size="45"
          :style="{ height: virtualScrollerHeight + 'px' }"
          key-field="id"
          v-slot="{ item: plant, index, active }"
          :buffer="2000"
        >
          <DynamicScrollerItem
            :item="plant"
            :active="active"
            :data-index="index"
            :data-active="active"
          >
            <LagerListItem :plant="plant" @update="handlePlantUpdate" class="px-2" />
          </DynamicScrollerItem>
        </DynamicScroller>
      </div>
    </div>
    <!-- Add plant modal -->
    <UModal v-model:open="addPlantModalOpen" title="Lägg till växt" class="p-4 overflow-hidden">
      <template #content>
        <div class="modal-slide-outer">
          <div
            class="modal-slide-inner"
            :class="slideDirection"
            :style="{ transform: addStep === 'pick' ? 'translateX(0%)' : 'translateX(-50%)' }"
          >
            <div class="modal-slide-step">
              <PlantPicker
                v-if="addStep === 'pick' || slideDirection === 'right'"
                :edit-value="newPlantFacitId || 0"
                :current-plant-i-d="0"
                @select="onPlantPickerSelect"
                @addSelect="onPlantPickerAddSelect"
              />
            </div>
            <div class="modal-slide-step">
              <div v-if="addStep === 'form' || slideDirection === 'left'">
                <div class="flex flex-col gap-4">
                  <UFormField label="Kommentar">
                    <UInput v-model="addForm.comment_by_plantskola" placeholder="" class="w-full" />
                  </UFormField>
                  <UFormField label="Kruka">
                    <UInput v-model="addForm.pot" placeholder="ex. C5" class="w-full" />
                  </UFormField>
                  <UFormField label="Höjd">
                    <UInput v-model="addForm.height" placeholder="ex. 100-120" class="w-full" />
                  </UFormField>
                  <UFormField label="Pris">
                    <UInput
                      v-model="addForm.price"
                      type="number"
                      placeholder="kr"
                      step="10"
                      class="w-full"
                    />
                  </UFormField>
                  <UFormField label="Lager">
                    <UInput v-model="addForm.stock" type="number" placeholder="st" class="w-full" />
                  </UFormField>
                </div>
                <div class="flex gap-2 justify-end mt-4">
                  <UButton
                    v-if="addStep === 'form'"
                    color="neutral"
                    variant="outline"
                    @click="addStep = 'pick'"
                    class="w-max"
                    icon="material-symbols:arrow-back-ios-new"
                  >
                    Tillbaka
                  </UButton>
                  <UButton
                    v-if="addStep === 'form'"
                    :loading="addPlantLoading"
                    @click="addPlantToLager"
                    color="primary"
                    class="flex-1"
                    icon="material-symbols:add"
                  >
                    Lägg till
                  </UButton>
                </div>
              </div>
            </div>
          </div>
        </div>
      </template>
    </UModal>

    <!-- Export Modal -->
    <UModal v-model:open="showExportModal" title="Exportera lager">
      <template #content>
        <div class="p-6 space-y-6">
          <!-- Export format selection -->
          <div class="space-y-3">
            <h3 class="text-lg font-semibold">Exportformat</h3>
            <USelect
              v-model="exportOptions.format"
              :items="exportFormatOptions"
              placeholder="Välj format"
              size="lg"
              value-attribute="value"
              class="w-full"
            />
            <div class="text-sm text-t-muted">
              <span v-if="exportOptions.format === 'csv'">
                CSV-format som kan öppnas i Excel eller Google Sheets
              </span>
              <span v-else-if="exportOptions.format === 'json'">
                JSON-format för teknisk användning eller API:er
              </span>
              <span v-else-if="exportOptions.format === 'txt'">
                Tab-separerat textformat som exporteras som vanlig textfil
              </span>
            </div>
          </div>

          <!-- Data scope selection -->
          <div class="space-y-3">
            <h3 class="text-lg font-semibold">Dataomfång</h3>
            <div class="flex flex-col gap-3">
              <UCheckbox
                v-model="exportOptions.onlyFiltered"
                :label="`Endast filtrerade växter (${filteredLager.length} av ${
                  lagerComplete?.length || 0
                } st)`"
                size="lg"
              />
              <UCheckbox
                v-model="exportOptions.includeHidden"
                label="Inkludera dolda växter"
                size="lg"
              />
            </div>
          </div>
          <!-- Field selection -->
          <div class="space-y-3">
            <h3 class="text-lg font-semibold">Fält att inkludera</h3>
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <UCheckbox
                v-for="field in exportFieldOptions"
                :key="field.key"
                v-model="exportOptions.includeFields[field.key]"
                :label="field.label"
                size="lg"
              />
            </div>
          </div>

          <!-- Action buttons -->
          <div class="flex gap-3 justify-end pt-4">
            <UButton
              color="neutral"
              variant="outline"
              @click="showExportModal = false"
              :disabled="exportLoading"
            >
              Avbryt
            </UButton>
            <UButton
              color="primary"
              icon="uil:export"
              :loading="exportLoading"
              @click="exportPlants"
              :disabled="!Object.values(exportOptions.includeFields).some(Boolean)"
            >
              Exportera
            </UButton>
          </div>
        </div>
      </template>
    </UModal>
    <!-- Delete Confirmation Modal -->
    <UModal v-model:open="showDeleteModal" title="Radera växter från lager">
      <template #content>
        <div class="p-6 space-y-6">
          <!-- Warning -->
          <div class="bg-error-50 border border-error-200 p-4 rounded-lg">
            <div class="flex items-start gap-3">
              <UIcon
                name="material-symbols:warning"
                class="text-error-500 text-xl flex-shrink-0 mt-0.5"
              />
              <div>
                <h4 class="font-semibold text-error-800 mb-1">Varning!</h4>
                <p class="text-error-700 text-sm">
                  Den här åtgärden kan inte ångras. Växterna kommer att raderas permanent från ditt
                  lager.
                </p>
              </div>
            </div>
          </div>

          <!-- Delete options -->
          <div class="space-y-4">
            <div class="space-y-3">
              <h3 class="text-lg font-semibold">Vad vill du radera?</h3>
              <div class="flex flex-col gap-3">
                <UCheckbox
                  v-model="deleteOptions.deleteFiltered"
                  :label="`Endast filtrerade växter (${
                    filteredLager.filter((p) => (!deleteOptions.includeHidden ? !p.hidden : true))
                      .length
                  } st)`"
                  size="lg"
                />
                <UCheckbox
                  v-model="deleteOptions.includeHidden"
                  label="Inkludera dolda växter i raderingen"
                  size="lg"
                />
              </div>
            </div>

            <!-- Preview of what will be deleted -->
            <div class="bg-bg-soft p-4 rounded-lg">
              <h4 class="font-semibold mb-2 text-error-600">Kommer att radera:</h4>
              <div class="text-sm text-t-muted space-y-1">
                <div class="font-medium text-error-700">
                  {{ deleteCount }} växt{{ deleteCount === 1 ? '' : 'er' }}
                </div>
                <div
                  v-if="
                    deleteOptions.deleteFiltered &&
                    (search || filterType || hasActiveAdvancedFilters)
                  "
                >
                  Baserat på nuvarande filter
                </div>
                <div v-if="deleteOptions.includeHidden">Inklusive dolda växter</div>
              </div>
            </div>
          </div>

          <!-- Action buttons -->
          <div class="flex gap-3 justify-end pt-4">
            <UButton
              color="neutral"
              variant="outline"
              @click="showDeleteModal = false"
              :disabled="deleteLoading"
            >
              Avbryt
            </UButton>
            <UButton
              color="error"
              icon="material-symbols:delete-forever"
              :loading="deleteLoading"
              @click="deleteMultiplePlants"
              :disabled="deleteCount === 0"
            >
              Radera {{ deleteCount }} växt{{ deleteCount === 1 ? '' : 'er' }}
            </UButton>
          </div>
        </div>
      </template>
    </UModal>
    <!-- Advanced Filters Modal -->
    <UModal v-model:open="showAdvancedFilters" title="Avancerade filter">
      <template #content>
        <div class="p-6 space-y-6">
          <!-- Price filters -->
          <div class="space-y-3">
            <h3 class="text-lg font-semibold">Pris</h3>
            <div class="grid grid-cols-2 gap-3">
              <UFormField label="Minpris">
                <UInput
                  v-model="advancedFilters.minPrice"
                  type="number"
                  placeholder="kr"
                  step="10"
                  :autofocus="false"
                />
              </UFormField>
              <UFormField label="Maxpris">
                <UInput
                  v-model="advancedFilters.maxPrice"
                  type="number"
                  placeholder="kr"
                  step="10"
                  :autofocus="false"
                />
              </UFormField>
            </div>
          </div>

          <!-- Stock filters -->
          <div class="space-y-3">
            <h3 class="text-lg font-semibold">Lager</h3>
            <div class="grid grid-cols-2 gap-3">
              <UFormField label="Minlager">
                <UInput
                  v-model="advancedFilters.minStock"
                  type="number"
                  placeholder="st"
                  :autofocus="false"
                />
              </UFormField>
              <UFormField label="Maxlager">
                <UInput
                  v-model="advancedFilters.maxStock"
                  type="number"
                  placeholder="st"
                  :autofocus="false"
                />
              </UFormField>
            </div>
          </div>

          <!-- Physical attributes -->
          <div class="space-y-3">
            <h3 class="text-lg font-semibold">Fysiska egenskaper</h3>
            <div class="grid grid-cols-2 gap-3">
              <UFormField label="Kruka">
                <UInput v-model="advancedFilters.pot" placeholder="ex. C5, P9" :autofocus="false" />
              </UFormField>
              <UFormField label="Höjd">
                <UInput
                  v-model="advancedFilters.height"
                  placeholder="ex. 100, 80-120"
                  :autofocus="false"
                />
              </UFormField>
            </div>
          </div>

          <!-- Comment filter -->
          <div class="space-y-3">
            <h3 class="text-lg font-semibold">Kommentar</h3>
            <USelect
              v-model="advancedFilters.hasComment"
              :items="commentFilterOptions"
              placeholder="Filtrera på kommentar"
              value-attribute="value"
              class="w-full"
            />
          </div>

          <!-- Action buttons -->
          <div class="flex gap-3 justify-end pt-4 border-t border-border">
            <UButton
              variant="outline"
              color="neutral"
              @click="clearAdvancedFilters"
              icon="material-symbols:clear-all"
            >
              Rensa alla
            </UButton>
            <UButton
              color="primary"
              @click="showAdvancedFilters = false"
              icon="material-symbols:check"
            >
              Tillämpa filter
            </UButton>
          </div>
        </div>
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

.slide-x-enter-active,
.slide-x-leave-active {
  transition: all 0.4s cubic-bezier(0.4, 0, 0.2, 1);
}
.slide-x-enter-from {
  transform: translateX(100%);
  opacity: 0;
}
.slide-x-leave-to {
  transform: translateX(-100%);
  opacity: 0;
}

.modal-slide-outer {
  overflow: hidden;
  width: 100%;
  position: relative;
  min-height: 350px;
}
.modal-slide-inner {
  display: flex;
  width: 200%;
  max-width: 200%;
  transition: transform 0.4s cubic-bezier(0.4, 0, 0.2, 1);
}
.modal-slide-step {
  width: 50%;
  max-width: 50%;
  flex-shrink: 0;
  box-sizing: border-box;
  overflow-x: auto;
}

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

@media screen and (min-width: 768px) {
  .vue-recycle-scroller__item-view:last-child li {
    border-color: transparent;
  }
  .vue-recycle-scroller__item-wrapper {
    border-bottom: 1px solid var(--ui-bg);
    /* border-color: transparent; */
  }
}

/* Optimize transitions for virtual scrolling */
.expand-fade-enter-active,
.expand-fade-leave-active {
  transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
}
.expand-fade-enter-from,
.expand-fade-leave-to {
  transform: translateY(-10px);
  max-height: 0;
  opacity: 0;
}
.expand-fade-enter-to,
.expand-fade-leave-from {
  max-height: 200px;
  opacity: 1;
}

/* Chromium-based browser detection and styles */
@supports (-webkit-appearance: none) and (not (-moz-appearance: none)) {
  /* Optimize virtual scrolling performance for Chromium */
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

.scroller-styles {
  scrollbar-width: thin;
  scrollbar-color: var(--ui-text-muted) transparent;

  /* Chrome, Edge, Safari */
  &::-webkit-scrollbar {
    height: 8px;
    background: #f8fafc;
    border-radius: 6px;
  }
  &::-webkit-scrollbar-thumb {
    background: var(--ui-text-muted);
    border-radius: 6px;
  }
  &::-webkit-scrollbar-thumb:hover {
    background: var(--ui-bg-accented);
  }
  &::-webkit-scrollbar-corner {
    background: transparent;
  }
}
@media screen and (max-width: 768px) {
  .lager-page input {
    font-size: 16px;
  }
}
</style>
