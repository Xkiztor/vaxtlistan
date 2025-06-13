<script setup lang="ts">
definePageMeta({
  layout: 'admin',
  middleware: 'plantskola-admin',
});
// --- Types ---
import type { Totallager, Facit, Plantskola, LagerComplete } from '~/types/supabase-tables';
import { DynamicScroller, DynamicScrollerItem } from 'vue-virtual-scroller';
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
const sortBy = ref<'name' | 'price' | 'stock' | 'height'>('name');
const sortOrder = ref<'asc' | 'desc'>('desc');
const sortOptions = [
  { value: 'name', label: 'Namn' },
  { value: 'price', label: 'Pris' },
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
    const navbarHeight = 80; // Approximate height of navbar
    const headerHeight = 100; // Approximate height of header, actions, filters
    const calculatedHeight = viewport - headerHeight - navbarHeight;
    virtualScrollerHeight.value = Math.min(800, Math.max(400, calculatedHeight));
  }
};

// Reset scroll position when filters change
watch(
  [search, filterType, sortBy, sortOrder, advancedFilters],
  () => {
    // TODO: Fix TypeScript issue with scrollToTop
    if (dynamicScrollerRef.value && typeof dynamicScrollerRef.value.scrollToTop === 'function') {
      dynamicScrollerRef.value.scrollToTop();
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
    if (!plantskola.value) return [];

    // Use the SQL function to get complete lager data with facit information
    const { data, error } = await supabase.rpc('get_plantskola_lager_complete', {
      p_plantskola_id: plantskola.value.id,
    } as any); // Type assertion to handle Supabase RPC parameter typing

    if (error || !data) return [];
    return data as LagerComplete[];
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
    result = result.filter((p) => p.price !== null && p.price >= advancedFilters.minPrice!);
  }
  if (advancedFilters.maxPrice !== null) {
    result = result.filter((p) => p.price !== null && p.price <= advancedFilters.maxPrice!);
  }
  if (advancedFilters.minStock !== null) {
    result = result.filter((p) => p.stock !== null && p.stock >= advancedFilters.minStock!);
  }
  if (advancedFilters.maxStock !== null) {
    result = result.filter((p) => p.stock !== null && p.stock <= advancedFilters.maxStock!);
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
      case 'name':
        aValue = a.facit_name || a.name_by_plantskola || '';
        bValue = b.facit_name || b.name_by_plantskola || '';
        // Reverse comparison for name sorting
        [aValue, bValue] = [bValue, aValue];
        break;
      case 'price':
        aValue = a.price || 0;
        bValue = b.price || 0;
        break;
      case 'stock':
        aValue = a.stock || 0;
        bValue = b.stock || 0;
        break;
      case 'height':
        // Extract numeric value from height string (e.g., "100-120" -> 100)
        aValue = parseFloat((a.height || '0').replace(/[^\d.-]/g, '')) || 0;
        bValue = parseFloat((b.height || '0').replace(/[^\d.-]/g, '')) || 0;
        break;
      default:
        return 0;
    }

    if (typeof aValue === 'string') {
      aValue = aValue.toLowerCase();
      bValue = bValue.toLowerCase();
    }

    const comparison = aValue < bValue ? -1 : aValue > bValue ? 1 : 0;
    return sortOrder.value === 'asc' ? comparison : -comparison;
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
  <div class="max-w-4xl mx-auto pt-8 md:px-4">
    <div class="flex flex-col md:flex-row md:items-end md:justify-between gap-4 mb-4 px-4">
      <div>
        <h1 class="text-3xl md:text-4xl font-black">Lager</h1>
        <div class="text-t-muted text-lg">
          Alla växter för {{ plantskola?.name || 'plantskola' }}
        </div>
      </div>
    </div>
    <div class="sticky top-20 z-10 bg-bg">
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
          class="flex md:flex-row gap-2 md:gap-4 overflow-x-scroll py-2"
          ref="actionsScrollerRef"
        >
          <UButton
            color="primary"
            :size="isMobile ? 'md' : 'xl'"
            icon="material-symbols:add"
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
            :disabled="!plantskola"
          >
            Exportera
          </UButton>
          <UButton
            color="neutral"
            :size="isMobile ? 'md' : 'xl'"
            class="min-w-max md:w-auto"
            variant="subtle"
            :disabled="!plantskola"
          >
            Exempel
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
          class="flex md:flex-row gap-2 md:gap-4 overflow-x-scroll py-2"
          ref="filtersScrollerRef"
        >
          <UInput
            v-model="search"
            placeholder="Sök"
            :size="isMobile ? 'md' : 'xl'"
            class="flex-1 min-w-40"
            icon="i-heroicons-magnifying-glass"
          />
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
            <UButton
              variant="outline"
              color="neutral"
              @click="sortOrder = sortOrder === 'asc' ? 'desc' : 'asc'"
              :icon="
                sortOrder === 'asc'
                  ? 'material-symbols:arrow-upward'
                  : 'material-symbols:arrow-downward'
              "
              :size="isMobile ? 'md' : 'xl'"
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
    <div v-else-if="filteredLager.length === 0" class="text-t-muted italic py-8 text-center">
      Inga växter hittades.
    </div>
    <div v-else class="md:border md:border-border md:rounded-lg md:mx-4 overflow-hidden">
      <!-- Virtual scroll container with dynamic sizing -->
      <DynamicScroller
        ref="dynamicScrollerRef"
        class="scroller pb-24"
        :items="filteredLager"
        :min-item-size="80"
        :style="{ height: virtualScrollerHeight + 'px' }"
        key-field="id"
        v-slot="{ item: plant, index, active }"
      >
        <DynamicScrollerItem
          :item="plant"
          :active="active"
          :size-dependencies="[
            plant.name_by_plantskola,
            plant.facit_sv_name,
            plant.facit_name,
            plant.comment_by_plantskola,
            plant.pot,
            plant.height,
            plant.price,
            plant.stock,
          ]"
          :data-index="index"
          :data-active="active"
        >
          <LagerListItem :plant="plant" @update="handlePlantUpdate" class="px-2" />
        </DynamicScrollerItem>
      </DynamicScroller>
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
                />
              </UFormField>
              <UFormField label="Maxpris">
                <UInput
                  v-model="advancedFilters.maxPrice"
                  type="number"
                  placeholder="kr"
                  step="10"
                />
              </UFormField>
            </div>
          </div>

          <!-- Stock filters -->
          <div class="space-y-3">
            <h3 class="text-lg font-semibold">Lager</h3>
            <div class="grid grid-cols-2 gap-3">
              <UFormField label="Minlager">
                <UInput v-model="advancedFilters.minStock" type="number" placeholder="st" />
              </UFormField>
              <UFormField label="Maxlager">
                <UInput v-model="advancedFilters.maxStock" type="number" placeholder="st" />
              </UFormField>
            </div>
          </div>

          <!-- Physical attributes -->
          <div class="space-y-3">
            <h3 class="text-lg font-semibold">Fysiska egenskaper</h3>
            <div class="grid grid-cols-2 gap-3">
              <UFormField label="Kruka">
                <UInput v-model="advancedFilters.pot" placeholder="ex. C5, P9" />
              </UFormField>
              <UFormField label="Höjd">
                <UInput v-model="advancedFilters.height" placeholder="ex. 100, 80-120" />
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
</style>
