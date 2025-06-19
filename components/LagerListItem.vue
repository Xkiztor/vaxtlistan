<script setup lang="ts">
// Component for displaying a single plant in lager
import type { LagerComplete } from '~/types/supabase-tables';
import { ref, computed } from 'vue';
import { useLagerStore } from '~/stores/lager';
import { usePlantType } from '~/composables/usePlantType';

const supabase = useSupabaseClient();
const user = useSupabaseUser();
const { width, height } = useWindowSize();
const props = defineProps<{ plant: LagerComplete }>();
const emit = defineEmits(['update']);

const lagerStore = useLagerStore();
const { getRhsTypeLabel, getAllRhsTypeLabels } = usePlantType();

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
  | 'comment_by_plantskola'
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
    error.value = lagerStore.error || 'Kunde inte uppdatera växt.';
    return;
  }
  // Emit update event to notify parent to refresh data
  emit('update');
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
    const updateData = { hidden: !props.plant.hidden };
    const { error } = await supabase
      .from('totallager')
      // @ts-expect-error - Supabase generated types issue
      .update(updateData)
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
  return props.plant.facit_name || '';
});

const plantSwedishName = computed(() => {
  return props.plant.facit_sv_name || '';
});

const plantTypes = computed(() => {
  return props.plant.facit_rhs_types || [];
});
</script>

<template>
  <li class="flex flex-col p-2 pl-4 border-border border-b transition-colors">
    <!-- Main Info -->
    <div
      class="flex-1 max-md:flex w-full md:grid md:grid-cols-[59%_37%_4%] xl:grid-cols-[37%_37%_23%_3%] place-items-center"
    >
      <div
        class="flex overflow-x-hidden relative min-w-0 flex-1 mr-1 items-center gap-2 max-md:gap-0 max-md:leading-5 max-md:flex-col max-md:items-start md:place-self-start"
      >
        <span
          class="font-semibold text-md md:text-lg min-w-0 flex-shrink"
          :class="{
            'text-t-toned flex items-center gap-2': plant.hidden,
            'overflow-hidden text-nowrap text-ellipsis': !isExpanded,
          }"
        >
          <UIcon
            v-if="plant.hidden"
            name="material-symbols:visibility-off"
            size="xs"
            class="flex-shrink-0"
          />
          {{ plantName }}
        </span>
        <span
          v-if="plantSwedishName"
          class="max-md:text-sm opacity-60 truncate min-w-0 flex-shrink"
          >{{ plantSwedishName }}</span
        >
        <div
          class="absolute md:hidden right-0 top-0 bottom-0 w-6 z-10 pointer-events-none bg-gradient-to-l from-bg to-transparent"
        ></div>
      </div>
      <!-- Stock and Price -->
      <!-- class="max-md:flex gap-2 max-md:flex-col max-md:items-end max-md:gap-1 max-md:text-xs md:text-md md:grid md:grid-cols-[60%_30%] md:w-full md:place-items-start md:gap-4 md:pr-4" -->
      <div
        class="max-xl:hidden grid grid-cols-[5%_50%_35%] gap-4 pr-4 w-full place-items-[center_start] text-nowrap whitespace-nowrap"
      >
        <div class="flex items-center gap-2">
          <UTooltip
            :delay-duration="0"
            :text="'Kommentar: ' + plant.comment_by_plantskola"
            v-if="plant.comment_by_plantskola"
          >
            <UIcon name="material-symbols:info-rounded" />
          </UTooltip>
        </div>
        <div class="flex items-center gap-2">
          <span>Höjd:</span>
          <span class="font-bold">{{ plant.height ? plant.height + ' cm' : '---' }}</span>
          <UButton
            v-if="canEdit"
            icon="i-heroicons-pencil-square"
            size="xs"
            color="primary"
            variant="ghost"
            class="p-0 opacity-60 hover:opacity-100"
            @click="openEdit('height', plant.height)"
          />
        </div>
        <div class="flex items-center gap-2">
          <span>Kruka:</span>
          <span class="font-bold">{{ plant.pot ? plant.pot : '---' }}</span>
          <UButton
            v-if="canEdit"
            icon="i-heroicons-pencil-square"
            size="xs"
            color="primary"
            variant="ghost"
            class="p-0 opacity-60 hover:opacity-100"
            @click="openEdit('pot', plant.pot)"
          />
        </div>
      </div>
      <div
        class="max-md:flex gap-2 max-md:flex-col max-md:items-end max-md:gap-1 max-md:text-xs md:text-md md:grid md:grid-cols-[60%_30%] md:w-full md:place-items-start md:gap-4 md:pr-4 text-nowrap whitespace-nowrap"
      >
        <div class="flex items-center gap-2" v-if="plant.stock !== undefined">
          Lager:
          <span class="font-black md:font-bold">{{ plant.stock ? plant.stock : '?' }}</span>
          <UButton
            v-if="canEdit"
            icon="i-heroicons-pencil-square"
            size="xs"
            color="primary"
            variant="ghost"
            class="p-0 scale-150 opacity-60 hover:opacity-100"
            :ui="{ leadingIcon: 'scale-[67%]' }"
            @click="openEdit('stock', plant.stock)"
          />
        </div>

        <div class="flex items-center gap-2" v-if="plant.price !== undefined">
          <span class="font-black md:font-bold">{{ plant.price ? plant.price : '-' }} kr</span>
          <UButton
            v-if="canEdit"
            icon="i-heroicons-pencil-square"
            size="xs"
            color="primary"
            variant="ghost"
            class="p-0 scale-150 opacity-60 hover:opacity-100"
            :ui="{ leadingIcon: 'scale-[67%]' }"
            @click="openEdit('price', plant.price)"
          />
        </div>
      </div>
      <!-- Expand/Collapse Button -->
      <UButton
        :icon="expandIcon"
        :ui="{ leadingIcon: '' }"
        size="xl"
        variant="ghost"
        color="neutral"
        class="ml-2 md:ml-0 p-0 hover:bg-transparent min-w-max w-max"
        aria-label="Expandera detaljer"
        @click="isExpanded = !isExpanded"
      />
    </div>

    <!-- Collapsible Details -->
    <Transition name="expand-fade">
      <div
        v-show="isExpanded"
        class="mt-2 pt-2 pr-2 border-t border-border/40 md:flex md:gap-4 md:flex-wrap xl:flex-nowrap md:gap-y-2 md:items-center xl:justify-between xl:pb-2 xl:pt-4 xl:mt-4"
      >
        <!-- Badges -->
        <div class="flex flex-wrap gap-2 xl:min-w-max">
          <!-- RHS Type badges -->
          <template v-for="label in getAllRhsTypeLabels(plantTypes)" :key="label">
            <UBadge color="primary" variant="subtle">
              {{ label }}
            </UBadge>
          </template>
          <UBadge class="flex items-center gap-2 xl:hidden" color="neutral" variant="subtle">
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
          <UBadge class="flex items-center gap-2 xl:hidden" color="neutral" variant="subtle">
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
        <div class="flex items-center gap-2 max-md:mt-2 xl:min-w-max">
          <span class="text-sm">
            <span class="text-t-toned">Kommentar:</span>
            {{ plant.comment_by_plantskola ? plant.comment_by_plantskola : '---' }}
          </span>
          <UButton
            v-if="canEdit"
            icon="i-heroicons-pencil-square"
            size="xs"
            color="primary"
            variant="ghost"
            @click="openEdit('comment_by_plantskola', plant.comment_by_plantskola)"
          />
        </div>
        <!-- Eget namn -->
        <div
          v-if="
            plant.name_by_plantskola &&
            plant.name_by_plantskola.toLocaleLowerCase() !== plantName.toLocaleLowerCase()
          "
          class="flex items-center gap-2 max-md:mt-2 xl:min-w-max"
        >
          <span class="text-sm">
            <span class="text-t-toned">Eget namn:</span>
            {{ plant.name_by_plantskola }}
          </span>
        </div>
        <div class="flex items-center gap-2 text-xs max-md:mt-2 text-t-muted xl:min-w-max">
          <span>
            <span>Tillagd: </span>
            <span>
              {{
                new Date(plant.created_at).toLocaleDateString('sv-SE', {
                  year: 'numeric',
                  month: '2-digit',
                  day: '2-digit',
                })
              }}
            </span>
          </span>
          <span v-if="plant.last_edited && plant.last_edited !== plant.created_at" class="ml-2">
            <span>Senast ändrad: </span>
            <span>
              {{
                new Date(plant.last_edited).toLocaleDateString('sv-SE', {
                  year: 'numeric',
                  month: '2-digit',
                  day: '2-digit',
                })
              }}
            </span>
          </span>
        </div>
        <!-- Actions -->
        <div class="flex items-center justify-end gap-2 max-md:mt-2 w-full max-xl:pt-2">
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
          <UButton
            icon="material-symbols:open-in-new-rounded"
            :to="`/vaxt/${plant.facit_id}/${plantName.replace(' ', '+')}/`"
            target="_blank"
            size="sm"
            variant="outline"
          ></UButton>
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
          <h2 class="text-lg font-semibold">
            {{
              editField
                ? {
                    comment_by_plantskola: 'Kommentar',
                    pot: 'Kruka',
                    height: 'Höjd',
                    price: 'Pris',
                    stock: 'Lager',
                  }[editField] || editField
                : ''
            }}
          </h2>
          <UInputNumber
            v-if="editField === 'price' || editField === 'stock'"
            v-model="editValue"
            :label="editField"
            :step="1"
            autofocus
            size="xl"
          />
          <UInput
            v-else
            v-model="editValue"
            :label="editField"
            :type="editField && ['price', 'stock'].includes(editField) ? 'number' : 'text'"
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
      @close="
        () => {
          showDeleteModal = false;
        }
      "
      :close="{
        onClick: () => {
          showDeleteModal = false;
        },
      }"
      :ui="{ content: 'p-4' }"
    >
      <template #content>
        <p>Är du säker på att du vill ta bort växten?</p>
        <div class="flex gap-2 justify-end mt-4">
          <UButton
            type="button"
            color="neutral"
            variant="ghost"
            @click="
              () => {
                showDeleteModal = false;
              }
            "
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
      @close="
        () => {
          showHideModal = false;
        }
      "
      :close="{
        onClick: () => {
          showHideModal = false;
        },
      }"
      :ui="{ content: 'p-4' }"
    >
      <template #content>
        <p>Är du säker på att du vill {{ plant.hidden ? 'visa' : 'dölja' }} växten?</p>
        <div class="flex gap-2 justify-end mt-4">
          <UButton
            type="button"
            color="neutral"
            variant="ghost"
            @click="
              () => {
                showHideModal = false;
              }
            "
          >
            Avbryt
          </UButton>
          <UButton
            type="button"
            :color="plant.hidden ? 'primary' : 'error'"
            :loading="hideLoading"
            @click="toggleHidePlant"
          >
            {{ plant.hidden ? 'Visa' : 'Dölj' }}
          </UButton>
        </div>
        <div v-if="hideError" class="text-error">{{ hideError }}</div>
      </template>
    </UModal>
  </li>
</template>

<style scoped>
/* Optimize for virtual scrolling - prevent layout shifts */
.expand-fade-enter-active,
.expand-fade-leave-active {
  transition: all 0.15s cubic-bezier(0.4, 0, 0.2, 1);
}
.expand-fade-enter-from,
.expand-fade-leave-to {
  transform: translateY(-5px);
  max-height: 0;
  opacity: 0;
}
.expand-fade-enter-to,
.expand-fade-leave-from {
  max-height: 150px;
  opacity: 1;
}

/* Ensure consistent sizing for virtual scroller */
li {
  contain: layout;
}
</style>
