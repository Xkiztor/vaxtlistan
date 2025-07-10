<script setup lang="ts">
// Component for displaying a single plant in lager
import type { LagerComplete } from '~/types/supabase-tables';
import { ref, computed } from 'vue';
import { useLagerStore } from '~/stores/lager';
import { usePlantType } from '~/composables/usePlantType';

const supabase = useSupabaseClient();
const user = useSupabaseUser();
const toast = useToast();
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

// State for three dot menu
const menuOpen = ref(false);

// State for duplicate action
const duplicateLoading = ref(false);
const duplicateError = ref<string | null>(null);

// State for custom field name editing
const editingFieldName = ref(false);
const newFieldName = ref('');
const fieldNameLoading = ref(false);
const fieldNameError = ref<string | null>(null);

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
  editingFieldName.value = false;
  fieldNameError.value = null;
};

// Open field name editor
const openEditFieldName = (fieldKey: string) => {
  editField.value = `custom_field_${fieldKey}`;
  newFieldName.value = fieldKey;
  editingFieldName.value = true;
  modalOpen.value = true;
  error.value = null;
  fieldNameError.value = null;
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
  editingFieldName.value = false;
  fieldNameError.value = null;
  newFieldName.value = '';
};

// Update custom field name across all lager items for this plantskola
const updateCustomFieldName = async () => {
  if (!editField.value || !editField.value.startsWith('custom_field_')) return;
  if (!newFieldName.value.trim()) {
    fieldNameError.value = 'Fältnamnet får inte vara tomt';
    return;
  }

  const oldFieldKey = editField.value.replace('custom_field_', '');
  const newFieldKey = newFieldName.value.trim();

  // Don't update if name hasn't changed
  if (oldFieldKey === newFieldKey) {
    editingFieldName.value = false;
    return;
  }

  fieldNameLoading.value = true;
  fieldNameError.value = null;

  try {
    // Get all lager items for this plantskola that have the old field name
    const { data: lagerItems, error: fetchError } = await supabase
      .from('totallager')
      .select('id, own_columns')
      .eq('plantskola_id', props.plant.plantskola_id)
      .not('own_columns', 'is', null);

    if (fetchError) throw new Error(fetchError.message);

    // Filter items that have the old field key
    const itemsToUpdate =
      (lagerItems as any)?.filter(
        (item: any) =>
          item.own_columns &&
          typeof item.own_columns === 'object' &&
          oldFieldKey in item.own_columns
      ) || [];

    if (itemsToUpdate.length === 0) {
      fieldNameError.value = 'Inga poster hittades med detta fältnamn';
      return;
    }

    // Update each item by renaming the field
    const updatePromises = itemsToUpdate.map(async (item: any) => {
      const ownColumns = item.own_columns as Record<string, any>;
      const updatedColumns = { ...ownColumns };

      // Move value from old key to new key
      if (oldFieldKey in updatedColumns) {
        updatedColumns[newFieldKey] = updatedColumns[oldFieldKey];
        delete updatedColumns[oldFieldKey];
      }

      // Update the database
      return (supabase.from('totallager') as any)
        .update({ own_columns: updatedColumns })
        .eq('id', item.id);
    });

    // Execute all updates
    const results = await Promise.all(updatePromises);

    // Check for errors
    const hasErrors = results.some((result) => result.error);
    if (hasErrors) {
      throw new Error('Kunde inte uppdatera alla poster');
    }

    // Emit update event to refresh data
    emit('update');

    // Close the editing mode
    editingFieldName.value = false;
    modalOpen.value = false;

    // Show success message
    toast.add({
      title: 'Fältnamn uppdaterat',
      description: `${itemsToUpdate.length} poster uppdaterade med det nya fältnamnet "${newFieldKey}"`,
      color: 'primary',
    });
  } catch (e: any) {
    fieldNameError.value = e.message || 'Kunde inte uppdatera fältnamnet';
  } finally {
    fieldNameLoading.value = false;
  }
};

// Update field in Lager Store
type EditableField =
  | 'name_by_plantskola'
  | 'comment_by_plantskola'
  | 'private_comment_by_plantskola'
  | 'id_by_plantskola'
  | 'pot'
  | 'height'
  | 'price'
  | 'stock'
  | 'facit_id';

const updateField = async () => {
  if (!editField.value) return;
  loading.value = true;
  error.value = null;

  // Handle custom fields separately
  if (editField.value.startsWith('custom_field_')) {
    const customFieldKey = editField.value.replace('custom_field_', '');
    const currentCustomFields = props.plant.own_columns || {};
    const updatedCustomFields = {
      ...currentCustomFields,
      [customFieldKey]: editValue.value,
    };
    try {
      const { error } = await supabase
        .from('totallager')
        // @ts-expect-error - Supabase generated types issue with JSONB
        .update({ own_columns: updatedCustomFields })
        .eq('id', props.plant.id);

      if (error) throw new Error(error.message);

      // Update local state if needed
      emit('update');
      closeEdit();
    } catch (e: any) {
      error.value = e.message || 'Kunde inte uppdatera anpassat fält.';
    } finally {
      loading.value = false;
    }
    return;
  }

  // Handle regular fields
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

// Duplicate plant handler
const duplicatePlant = async () => {
  duplicateLoading.value = true;
  duplicateError.value = null;
  try {
    // Only include columns that exist in totallager
    const totallagerFields = [
      'facit_id',
      'plantskola_id',
      'name_by_plantskola',
      'comment_by_plantskola',
      'private_comment_by_plantskola',
      'id_by_plantskola',
      'pot',
      'height',
      'price',
      'hidden',
      'stock',
      'own_columns',
    ];
    const newPlant: Record<string, any> = {};
    for (const key of totallagerFields) {
      // Copy stock value from original plant
      if (key in props.plant) {
        newPlant[key] = (props.plant as any)[key];
      }
    }
    newPlant.created_at = new Date().toISOString();
    newPlant.last_edited = newPlant.created_at;
    // Insert new plant
    const { error } = await (supabase.from('totallager') as any).insert([newPlant]);
    if (error) throw new Error(error.message);
    emit('update');
    menuOpen.value = false;
  } catch (e: any) {
    duplicateError.value = e.message || 'Kunde inte duplicera växt.';
  } finally {
    duplicateLoading.value = false;
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

// Helper to display custom fields
const customFields = computed(() => {
  if (!props.plant.own_columns) return [];
  return Object.entries(props.plant.own_columns).map(([key, value]) => ({
    key,
    value,
    displayKey: key.charAt(0).toUpperCase() + key.slice(1).replace(/_/g, ' '),
  }));
});

// Helper to check if plant has any private comments or custom data
const hasPrivateData = computed(() => {
  return (
    props.plant.private_comment_by_plantskola ||
    props.plant.id_by_plantskola ||
    (props.plant.own_columns && Object.keys(props.plant.own_columns).length > 0)
  );
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
        class="max-xl:hidden grid grid-cols-[10%_45%_35%] gap-4 pr-4 w-full place-items-[center_start] text-nowrap whitespace-nowrap"
      >
        <div class="flex items-center justify-between gap-2 mr-2">
          <UTooltip
            :delay-duration="0"
            :text="'Kommentar: ' + plant.comment_by_plantskola"
            v-if="plant.comment_by_plantskola"
          >
            <UIcon name="material-symbols:info-rounded" />
          </UTooltip>
          <div v-else></div>
          <UTooltip
            :delay-duration="0"
            :text="'Privat kommentar: ' + plant.private_comment_by_plantskola"
            v-if="plant.private_comment_by_plantskola"
          >
            <UIcon name="material-symbols:account-circle" class="" />
          </UTooltip>
          <div v-else></div>
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
        class="mt-2 pt-2 pr-2 border-t border-border/40 dark:border-border/70"
      >
        <!-- Plant Type Badges -->
        <div class="flex flex-wrap gap-2 xl:hidden">
          <!-- RHS Type badges -->
          <div v-for="label in getAllRhsTypeLabels(plantTypes)" :key="label">
            <UBadge color="primary" variant="subtle">
              {{ label }}
            </UBadge>
          </div>

          <!-- Mobile-only badges for basic info -->
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

        <!-- Plant Information Grid -->
        <div class="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
          <!-- RHS Type badges -->
          <div v-for="label in getAllRhsTypeLabels(plantTypes)" :key="label" class="max-xl:hidden">
            <UBadge color="primary" variant="subtle">
              {{ label }}
            </UBadge>
          </div>
          <!-- Public Comment -->
          <div class="flex items-center gap-2">
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
          <!-- Private Comment (always visible when can edit) -->
          <div v-if="canEdit" class="flex items-center gap-2">
            <span class="text-sm">
              <span class="text-t-toned">Privat kommentar:</span>
              {{
                plant.private_comment_by_plantskola ? plant.private_comment_by_plantskola : '---'
              }}
            </span>
            <UButton
              v-if="canEdit"
              icon="i-heroicons-pencil-square"
              size="xs"
              color="primary"
              variant="ghost"
              @click="
                openEdit('private_comment_by_plantskola', plant.private_comment_by_plantskola)
              "
            />
          </div>

          <!-- Custom ID by Plantskola -->
          <div v-if="plant.id_by_plantskola || canEdit" class="flex items-center gap-2">
            <span class="text-sm">
              <span class="text-t-toned">Eget ID:</span>
              {{ plant.id_by_plantskola ? plant.id_by_plantskola : '---' }}
            </span>
            <UButton
              v-if="canEdit"
              icon="i-heroicons-pencil-square"
              size="xs"
              color="primary"
              variant="ghost"
              @click="openEdit('id_by_plantskola', plant.id_by_plantskola)"
            />
          </div>

          <!-- Grupp -->
          <div v-if="plant.facit_grupp" class="flex items-center gap-2">
            <span class="text-sm">
              <span class="text-t-toned">Grupp:</span>
              {{ plant.facit_grupp }}
            </span>
          </div>

          <!-- Serie (if available in future) -->
          <div v-if="plant.facit_serie" class="flex items-center gap-2">
            <span class="text-sm">
              <span class="text-t-toned">Serie:</span>
              {{ plant.facit_serie }}
            </span>
          </div>

          <!-- Custom Name -->
          <div
            v-if="
              plant.name_by_plantskola &&
              plant.name_by_plantskola.toLocaleLowerCase() !== plantName.toLocaleLowerCase()
            "
            class="flex items-center gap-2"
          >
            <span class="text-sm">
              <span class="text-t-toned">Eget namn:</span>
              {{ plant.name_by_plantskola }}
            </span>
            <UButton
              v-if="canEdit"
              icon="i-heroicons-pencil-square"
              size="xs"
              color="primary"
              variant="ghost"
              @click="openEdit('name_by_plantskola', plant.name_by_plantskola)"
            />
          </div>
          <!-- Custom Fields (JSONB data) -->
          <div v-if="customFields.length > 0" class="">
            <h4 class="text-sm font-semibold text-t-toned">Anpassade fält:</h4>
            <div class="flex flex-wrap gap-x-2">
              <div v-for="field in customFields" :key="field.key" class="flex items-center gap-1">
                <span class="text-sm">
                  <span class="text-t-toned cursor-pointer group relative">
                    {{ field.displayKey }}:
                    <UButton
                      v-if="canEdit"
                      icon="i-heroicons-pencil-square"
                      size="xs"
                      color="neutral"
                      variant="ghost"
                      class="opacity-0 group-hover:opacity-60 hover:!opacity-100 transition-opacity ml-1"
                      @click="openEditFieldName(field.key)"
                      :ui="{ leadingIcon: 'scale-75' }"
                    />
                  </span>
                  {{ field.value }}
                </span>
                <UButton
                  v-if="canEdit"
                  icon="i-heroicons-pencil-square"
                  size="xs"
                  color="primary"
                  variant="ghost"
                  @click="openEdit(`custom_field_${field.key}`, field.value)"
                />
              </div>
            </div>
          </div>
        </div>

        <div class="flex items-center justify-end gap-x-2 mb-2">
          <span v-if="plant.created_at" class="text-t-muted text-xs">
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
          <span
            v-if="plant.last_edited && plant.last_edited !== plant.created_at"
            class="text-t-muted text-xs"
          >
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
          <!-- Plant Database ID -->
          <span class="text-t-muted text-xs">
            <UTooltip text="ID för den valda växten i vårt facit" :delay-duration="0">
              <span class="w-fit">
                <span>Växt-ID: </span>
                <span>{{ plant.facit_id }}</span>
              </span>
            </UTooltip>
          </span>
          <span class="text-t-muted text-xs">
            <UTooltip text="ID för växten i ert lager" :delay-duration="0">
              <span class="w-fit">
                <span>Varu-ID: </span>
                <span>{{ plant.id }}</span>
              </span>
            </UTooltip>
          </span>
        </div>
        <!-- Actions -->
        <div
          class="flex items-center justify-end gap-2 pt-3 border-t border-border/40 dark:border-border/70"
        >
          <!-- Three dot menu for more actions -->
          <UDropdownMenu
            v-model:open="menuOpen"
            :items="[
              [
                {
                  label: 'Duplicera växt',
                  icon: 'i-heroicons-document-duplicate',
                  onSelect: duplicatePlant,
                  disabled: duplicateLoading,
                },
                {
                  label: 'Byt växt',
                  icon: 'stash:arrows-switch-solid',
                  onSelect: () => openEdit('facit_id', plant.facit_id),
                },
              ],
              [
                {
                  label: 'Ta bort växt',
                  icon: 'ic:round-delete-forever',
                  color: 'error',
                  onSelect: () => (showDeleteModal = true),
                },
              ],
            ]"
            :ui="{}"
            placement="bottom-end"
            class="md:hidden"
          >
            <UButton
              icon="tabler:dots-vertical"
              size="sm"
              color="neutral"
              variant="outline"
              aria-label="Fler åtgärder"
              >Fler åtgärder</UButton
            >
          </UDropdownMenu>
          <UButton
            v-if="canEdit"
            class="max-md:hidden"
            icon="i-heroicons-document-duplicate"
            size="sm"
            color="primary"
            variant="outline"
            @click="duplicatePlant"
            >Duplicera</UButton
          >
          <UButton
            v-if="canEdit"
            class="max-md:hidden"
            icon="stash:arrows-switch-solid"
            size="sm"
            color="primary"
            variant="outline"
            @click="openEdit('facit_id', plant.facit_id)"
          >
            Byt växt
          </UButton>
          <UButton
            icon="ic:round-delete-forever"
            class="max-md:hidden"
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
            @click="toggleHidePlant()"
          >
            {{ plant.hidden ? 'Visa' : 'Dölj' }}
          </UButton>
          <UButton
            icon="material-symbols:open-in-new-rounded"
            :to="`/vaxt/${plant.facit_id}/${plantName.replace(' ', '+')}/`"
            target="_blank"
            size="sm"
            variant="outline"
            aria-label="Öppna växtinformation i ny flik"
          ></UButton>
        </div>
        <div v-if="duplicateError" class="text-error text-sm mt-2">{{ duplicateError }}</div>
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
        <div v-if="editingFieldName">
          <h2 class="text-lg font-semibold">Redigera fältnamn</h2>
          <p class="text-sm text-t-muted mb-4">
            Detta kommer att uppdatera fältnamnet för alla växter i ert lager som använder detta
            fält.
          </p>

          <UInput
            v-model="newFieldName"
            placeholder="Nytt fältnamn"
            autofocus
            size="xl"
            class="mb-4"
          />

          <div class="flex gap-2 justify-end">
            <UButton type="button" color="neutral" variant="ghost" @click="closeEdit">
              Avbryt
            </UButton>
            <UButton
              type="button"
              color="primary"
              :loading="fieldNameLoading"
              :disabled="
                !newFieldName.trim() ||
                newFieldName.trim() === (editField?.replace('custom_field_', '') || '')
              "
              @click="updateCustomFieldName"
            >
              Uppdatera fältnamn
            </UButton>
          </div>
          <div v-if="fieldNameError" class="text-error mt-2">{{ fieldNameError }}</div>
        </div>
        <div v-else-if="editField === 'facit_id'">
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
                ? editField.startsWith('custom_field_')
                  ? customFields.find((f) => f.key === editField?.replace('custom_field_', ''))
                      ?.displayKey || 'Anpassat fält'
                  : {
                      comment_by_plantskola: 'Kommentar',
                      private_comment_by_plantskola: 'Privat kommentar',
                      id_by_plantskola: 'Artikel-nummer',
                      name_by_plantskola: 'Eget namn',
                      pot: 'Kruka',
                      height: 'Höjd',
                      price: 'Pris',
                      stock: 'Lager',
                    }[editField] || editField
                : ''
            }}
          </h2>

          <!-- Helper text for private comment -->
          <p v-if="editField === 'private_comment_by_plantskola'" class="text-sm text-t-muted">
            Denna kommentar är endast synlig för dig och visas inte för kunder.
          </p>

          <!-- Helper text for article number -->
          <p v-if="editField === 'id_by_plantskola'" class="text-sm text-t-muted">
            Internt artikel-nummer eller kod för denna växt.
          </p>

          <!-- Helper text for custom fields -->
          <p v-if="editField && editField.startsWith('custom_field_')" class="text-sm text-t-muted">
            Anpassat fält som du kan redigera enligt dina behov.
          </p>

          <UTextarea
            v-if="
              editField === 'comment_by_plantskola' || editField === 'private_comment_by_plantskola'
            "
            v-model="editValue"
            :placeholder="
              editField === 'private_comment_by_plantskola' ? 'Privat kommentar...' : 'Kommentar...'
            "
            autofocus
            size="xl"
            :rows="3"
          />
          <UInputNumber
            v-else-if="editField === 'price' || editField === 'stock'"
            v-model="editValue"
            :step="1"
            autofocus
            size="xl"
            :placeholder="editField === 'price' ? 'Pris i kronor' : 'Antal i lager'"
          />
          <UInput
            v-else
            v-model="editValue"
            :type="editField && ['price', 'stock'].includes(editField) ? 'number' : 'text'"
            :placeholder="
              editField && editField.startsWith('custom_field_')
                ? `Värde för ${
                    customFields.find((f) => f.key === editField?.replace('custom_field_', ''))
                      ?.displayKey || 'anpassat fält'
                  }`
                : editField === 'id_by_plantskola'
                ? 'Artikel-nummer'
                : editField === 'name_by_plantskola'
                ? 'Eget namn på växten'
                : editField === 'pot'
                ? 'Kruka storlek/typ'
                : editField === 'height'
                ? 'Höjd i cm'
                : ''
            "
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
        <p class="border-none border-0">Är du säker på att du vill ta bort växten?</p>
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
