<script setup lang="ts">
// Component for displaying a single plant in lager
import type { Totallager, Facit } from '~/types/supabase-tables';
import { ref, computed } from 'vue';
import { useLagerStore } from '~/stores/lager';
import { usePlantType } from '~/composables/usePlantType';
const supabase = useSupabaseClient();
const user = useSupabaseUser();
const { width, height } = useWindowSize();
const props = defineProps<{ plant: Totallager }>();
// const props = defineProps<{ plant: Totallager; facit: Facit[] }>();
const emit = defineEmits(['update']);

const facitStore = useFacitStore();
const { data: facit } = await useAsyncData('allFacit', () => facitStore.fetchFacit(supabase));

const lagerStore = useLagerStore();
const { letterToType } = usePlantType();

// State
const isExpanded = ref(false);

// State for editing fields
const modalOpen = ref(false);
const editField = ref<string | null>(null);
const editValue = ref<any>(null);
const loading = ref(false);
const error = ref<string | null>(null);

// State for delete/hide modals
const showDeleteModal = ref(false);
const showHideModal = ref(false);
const hideLoading = ref(false);
const deleteLoading = ref(false);
const hideError = ref<string | null>(null);
const deleteError = ref<string | null>(null);

// Icon for expand/collapse
const expandIcon = computed(() =>
  isExpanded.value ? 'material-symbols:expand-less-rounded' : 'material-symbols:expand-more-rounded'
);

// Helper: check if user can edit (plantskola owner)
const canEdit = computed(() => {
  // You may want to pass plantskola.user_id as a prop for strict check
  return !!user.value;
});

// Open modal for a field
const openEdit = (field: string, value: any) => {
  if (field === 'facit_id') {
    modalOpen.value = true;
    editField.value = field;
    editValue.value = value;
    error.value = null;
    return;
  }
  modalOpen.value = true;
  editField.value = field;
  editValue.value = value;
  error.value = null;
};

// PlantPicker select handler
const onPlantSelect = (id: number) => {
  editValue.value = id;
};
const isAdding = ref(false);
// PlantPicker add handler
const onAddPlantSelect = async (id: number) => {
  isAdding.value = true;
  editValue.value = id;
  console.log('Adding plant with ID:', id);
  await updateField();
};

// Close modal
const closeEdit = () => {
  modalOpen.value = false;
  editField.value = null;
  editValue.value = null;
  error.value = null;
};

// Update field in Lager Store
type EditableField =
  | 'name_by_plantskola'
  | 'description_by_plantskola'
  | 'pot'
  | 'height'
  | 'price'
  | 'stock'
  | 'facit_id';

const updateField = async () => {
  if (!editField.value) return;
  loading.value = true;
  error.value = null;
  let field = editField.value as EditableField;
  const success = await lagerStore.updateLagerField(
    supabase,
    props.plant.id,
    field,
    editValue.value
  );
  loading.value = false;
  if (!success) {
    error.value = lagerStore.error.value || 'Kunde inte uppdatera växt.';
    return;
  }
  closeEdit();
};

// Delete plant from lager
const deletePlant = async () => {
  deleteLoading.value = true;
  deleteError.value = null;
  try {
    const { error } = await supabase.from('totallager').delete().eq('id', props.plant.id);
    if (error) throw new Error(error.message);
    lagerStore.removePlantFromLager(props.plant.id); // update local state
    emit('update');
    showDeleteModal.value = false;
  } catch (e: any) {
    deleteError.value = e.message || 'Kunde inte ta bort växt.';
  } finally {
    deleteLoading.value = false;
  }
};

// Hide/unhide plant in lager
const toggleHidePlant = async () => {
  hideLoading.value = true;
  hideError.value = null;
  try {
    const { error } = await supabase
      .from('totallager')
      .update({ hidden: !props.plant.hidden })
      .eq('id', props.plant.id);
    if (error) throw new Error(error.message);
    lagerStore.setPlantHiddenState(props.plant.id, !props.plant.hidden); // update local state
    emit('update');
    showHideModal.value = false;
  } catch (e: any) {
    hideError.value = e.message || 'Kunde inte uppdatera växt.';
  } finally {
    hideLoading.value = false;
  }
};

const plantName = computed(() => {
  const facitItem = facit.value?.find((item) => item.id === props.plant.facit_id);
  return facitItem ? facitItem.name : '';
});
</script>

<template>
  <li class="flex flex-col p-2 rounded-lg bg-bg-elevated border-1 border-border transition-colors">
    <!-- Main Info -->
    <div class="flex-1 flex">
      <div class="flex flex-1 items-center gap-2 max-md:gap-0 max-md:flex-col max-md:items-start">
        <span
          class="font-bold text-md md:text-lg"
          :class="{ 'text-t-toned flex items-center gap-2': plant.hidden }"
        >
          <UIcon v-if="plant.hidden" name="material-symbols:visibility-off" size="xs" class="" />
          {{ plantName }}
        </span>

        <span class="max-md:text-sm">{{
          facit?.find((item) => item.id === plant.facit_id)?.sv_name || ''
        }}</span>
        <span v-if="plant.name_by_plantskola"> ({{ plant.name_by_plantskola }})</span>
      </div>
      <!-- Stock and Price -->
      <div class="flex items-center gap-2 max-md:flex-col max-md:items-end max-md:gap-1">
        <UBadge
          class="flex items-center gap-2"
          v-if="plant.stock !== undefined"
          :color="plant.stock > 0 ? 'neutral' : 'error'"
          :size="width < 550 ? 'md' : 'lg'"
          variant="subtle"
          >Lager: <span class="font-black">{{ plant.stock }} st</span>
          <UButton
            v-if="canEdit"
            icon="i-heroicons-pencil-square"
            size="xs"
            color="primary"
            variant="ghost"
            class="p-0"
            @click="openEdit('stock', plant.stock)"
          />
        </UBadge>

        <UBadge
          class="flex items-center gap-2"
          v-if="plant.price !== undefined"
          color="neutral"
          :size="width < 550 ? 'md' : 'lg'"
          variant="subtle"
        >
          <span class="font-black">{{ plant.price }} kr</span>
          <UButton
            v-if="canEdit"
            icon="i-heroicons-pencil-square"
            size="xs"
            color="primary"
            variant="ghost"
            class="p-0"
            @click="openEdit('price', plant.price)"
          />
        </UBadge>
      </div>
      <!-- Expand/Collapse Button -->
      <UButton
        :icon="expandIcon"
        :ui="{ leadingIcon: '' }"
        size="xl"
        variant="ghost"
        color="neutral"
        class="ml-2 md:ml-4 p-0 md:pr-2"
        aria-label="Expandera detaljer"
        @click="isExpanded = !isExpanded"
      />
    </div>

    <!-- Collapsible Details -->
    <Transition name="expand-fade">
      <div v-show="isExpanded" class="border-t-1 border-border mt-4 pt-4">
        <!-- Badges -->
        <div class="flex flex-wrap gap-2">
          <UBadge
            :color="
              letterToType(facit?.find((item) => item.id === plant.facit_id)?.type || '')
                .toLowerCase()
                .replace(/å/g, 'a')
                .replace(/ä/g, 'a')
                .replace(/ö/g, 'o')
            "
            variant="subtle"
            :class="
              letterToType(facit?.find((item) => item.id === plant.facit_id)?.type || '')
                .toLowerCase()
                .replace(/å/g, 'a')
                .replace(/ä/g, 'a')
                .replace(/ö/g, 'o')
            "
          >
            {{ letterToType(facit?.find((item) => item.id === plant.facit_id)?.type || '') }}
          </UBadge>
          <UBadge class="flex items-center gap-2" color="neutral" variant="subtle">
            Kruka: {{ plant.pot ? plant.pot : '---' }}
            <UButton
              v-if="canEdit"
              icon="i-heroicons-pencil-square"
              size="sm"
              color="primary"
              variant="ghost"
              class="p-0"
              @click="openEdit('pot', plant.pot)"
            />
          </UBadge>
          <UBadge class="flex items-center gap-2" color="neutral" variant="subtle">
            Höjd: {{ plant.height ? plant.height + ' cm' : '---' }}
            <UButton
              v-if="canEdit"
              icon="i-heroicons-pencil-square"
              size="xs"
              color="primary"
              variant="ghost"
              class="p-0"
              @click="openEdit('height', plant.height)"
            />
          </UBadge>
        </div>
        <!-- Description -->
        <div class="flex items-center gap-2 mt-2">
          <span class="text-sm">
            <span class="text-t-toned">Beskrivning:</span>
            {{ plant.description_by_plantskola ? plant.description_by_plantskola : '---' }}
          </span>
          <UButton
            v-if="canEdit"
            icon="i-heroicons-pencil-square"
            size="xs"
            color="primary"
            variant="ghost"
            @click="openEdit('description_by_plantskola', plant.description_by_plantskola)"
          />
        </div>
        <!-- Actions -->
        <div class="flex items-center justify-end gap-2 mt-4 w-full border-t-1 border-border pt-2">
          <UButton
            v-if="canEdit"
            icon="i-heroicons-pencil-square"
            size="sm"
            color="primary"
            variant="outline"
            @click="openEdit('facit_id', plant.facit_id)"
          >
            Byt växt
          </UButton>
          <UButton
            icon="ic:round-delete-forever"
            size="sm"
            color="error"
            variant="outline"
            @click="showDeleteModal = true"
          >
            Ta bort
          </UButton>
          <UButton
            :icon="plant.hidden ? 'material-symbols:visibility' : 'material-symbols:visibility-off'"
            size="sm"
            :color="plant.hidden ? 'neutral' : 'warning'"
            variant="outline"
            @click="showHideModal = true"
          >
            {{ plant.hidden ? 'Visa' : 'Dölj' }}
          </UButton>
        </div>
      </div>
    </Transition>

    <!-- Edit Modal -->
    <UModal
      v-model:open="modalOpen"
      title="Redigera"
      @close="closeEdit"
      :close="{ onClick: closeEdit }"
      :ui="{ content: 'p-4' }"
    >
      <template #content>
        <div v-if="editField === 'facit_id'">
          <PlantPicker
            @select="onPlantSelect"
            @addSelect="onAddPlantSelect"
            :editValue="editValue"
            :currentPlantID="plant.facit_id"
          />
          <div class="flex gap-2 justify-end mt-4">
            <UButton type="button" color="neutral" variant="ghost" @click="closeEdit">
              Avbryt
            </UButton>
            <UButton
              type="button"
              color="primary"
              :loading="loading"
              :disabled="!editValue || editValue === plant.facit_id"
              @click="updateField"
            >
              Spara
            </UButton>
          </div>
          <div v-if="error" class="text-error">{{ error }}</div>
        </div>
        <form v-else @submit.prevent="updateField" class="flex flex-col gap-4">
          <UInputNumber
            v-if="editField === 'price' || editField === 'stock'"
            v-model="editValue"
            :label="editField"
            :step="editField === 'price' ? 10 : 1"
            required
            autofocus
            size="xl"
          />
          <UInput
            v-else
            v-model="editValue"
            :label="editField"
            :type="['price', 'stock'].includes(editField) ? 'number' : 'text'"
            required
            autofocus
            size="xl"
          />

          <div class="flex gap-2 justify-end">
            <UButton type="button" color="neutral" variant="ghost" @click="closeEdit"
              >Avbryt</UButton
            >
            <UButton type="submit" color="primary" :loading="loading">Spara</UButton>
          </div>
          <div v-if="error" class="text-error">{{ error }}</div>
        </form>
      </template>
    </UModal>

    <!-- Delete Modal -->
    <UModal
      v-model:open="showDeleteModal"
      title="Ta bort växt"
      @close="() => (showDeleteModal = false)"
      :close="{ onClick: () => (showDeleteModal = false) }"
      :ui="{ content: 'p-4' }"
    >
      <template #content>
        <p>Är du säker på att du vill ta bort växten?</p>
        <div class="flex gap-2 justify-end mt-4">
          <UButton
            type="button"
            color="neutral"
            variant="ghost"
            @click="() => (showDeleteModal = false)"
          >
            Avbryt
          </UButton>
          <UButton type="button" color="error" :loading="deleteLoading" @click="deletePlant">
            Ta bort
          </UButton>
        </div>
        <div v-if="deleteError" class="text-error">{{ deleteError }}</div>
      </template>
    </UModal>

    <!-- Hide Modal -->
    <UModal
      v-model:open="showHideModal"
      title="Dölj/Visa växt"
      @close="() => (showHideModal = false)"
      :close="{ onClick: () => (showHideModal = false) }"
      :ui="{ content: 'p-4' }"
    >
      <template #content>
        <p>Är du säker på att du vill {{ plant.hidden ? 'visa' : 'dölja' }} växten?</p>
        <div class="flex gap-2 justify-end mt-4">
          <UButton
            type="button"
            color="neutral"
            variant="ghost"
            @click="() => (showHideModal = false)"
          >
            Avbryt
          </UButton>
          <UButton type="button" color="warning" :loading="hideLoading" @click="toggleHidePlant">
            {{ plant.hidden ? 'Visa' : 'Dölj' }}
          </UButton>
        </div>
        <div v-if="hideError" class="text-error">{{ hideError }}</div>
      </template>
    </UModal>
  </li>
</template>

<style scoped>
/* Only use Nuxt UI and Tailwind classes */
.expand-fade-enter-active,
.expand-fade-leave-active {
  transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1), transform 0.4s cubic-bezier(0.4, 0, 0.2, 1);
}
.expand-fade-enter-from,
.expand-fade-leave-to {
  transform: translateY(-20px);
  max-height: 0;
  opacity: 0;
}
.expand-fade-enter-to,
.expand-fade-leave-from {
  max-height: 500px;
  opacity: 1;
}
</style>
