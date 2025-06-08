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

// --- Add new plant to lager (two-step modal) ---
const addPlantModalOpen = ref(false); // Modal open state
const addStep = ref<'pick' | 'form'>('pick'); // Step: 'pick' or 'form'
const prevStep = ref<'pick' | 'form'>('pick'); // Track previous step for direction
const newPlantFacitId = ref<number | null>(null); // Selected facit id
const addPlantLoading = ref(false); // Loading state for save
const addForm = reactive({
  name_by_plantskola: '',
  description_by_plantskola: '',
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
  addForm.description_by_plantskola = '';
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

// Save new plant to lager
const addPlantToLager = async () => {
  if (!plantskola.value || !newPlantFacitId.value) return;
  // Validate required fields
  if (!addForm.price || !addForm.stock) {
    useToast().add({
      title: 'Fel',
      description: 'Pris och lager är obligatoriska.',
      color: 'error',
    });
    return;
  }
  addPlantLoading.value = true;
  const result = await lagerStore.addPlantToLager(supabase, {
    facit_id: newPlantFacitId.value,
    plantskola_id: plantskola.value.id,
    name_by_plantskola: addForm.name_by_plantskola,
    description_by_plantskola: addForm.description_by_plantskola,
    pot: addForm.pot,
    height: addForm.height,
    price: addForm.price,
    stock: addForm.stock,
    hidden: false,
    created_at: new Date().toISOString(),
    last_edited: new Date().toISOString(),
  });
  addPlantLoading.value = false;
  if (!result) {
    useToast().add({
      title: 'Fel',
      description: lagerStore.error.value || 'Kunde inte lägga till växt.',
      color: 'error',
    });
    return;
  }
  addPlantModalOpen.value = false;
  resetAddModal();
  useToast().add({ title: 'Växt tillagd', color: 'primary' });
};
</script>

<template>
  <div class="max-w-4xl mx-auto py-10 px-4">
    <div class="flex flex-col md:flex-row md:items-end md:justify-between gap-4 mb-8">
      <div>
        <h1 class="text-3xl md:text-4xl font-black">Lager</h1>
        <div class="text-t-muted text-lg">
          Alla växter för {{ plantskola?.name || 'plantskola' }}
        </div>
      </div>
      <!-- Add Plant Button: Professional, accessible, disables if not ready -->
      <UButton
        color="primary"
        size="xl"
        icon="material-symbols:add"
        class="w-full md:w-auto"
        :disabled="!plantskola || lagerStore.status === 'pending'"
        @click="openAddModal"
      >
        Lägg till växt
      </UButton>
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
    <div v-else class="text-t-muted italic py-8 text-center">Inga växter hittades.</div>
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
                @select="onPlantPickerSelect"
                @addSelect="onPlantPickerAddSelect"
              />
            </div>
            <div class="modal-slide-step">
              <div v-if="addStep === 'form' || slideDirection === 'left'">
                <div class="flex flex-col gap-4">
                  <UFormField label="Beskrivning (valfritt)">
                    <UInput
                      v-model="addForm.description_by_plantskola"
                      placeholder=""
                      class="w-full"
                    />
                  </UFormField>
                  <UFormField label="Kruka (valfritt)">
                    <UInput v-model="addForm.pot" placeholder="ex. C5" class="w-full" />
                  </UFormField>
                  <UFormField label="Höjd (valfritt)">
                    <UInput v-model="addForm.height" placeholder="ex. 100-120" class="w-full" />
                  </UFormField>
                  <UFormField label="Pris" required>
                    <UInput
                      v-model="addForm.price"
                      type="number"
                      placeholder="kr"
                      step="10"
                      class="w-full"
                    />
                  </UFormField>
                  <UFormField label="Lager" required>
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
                    :disabled="!addForm.price || !addForm.stock"
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
</style>
