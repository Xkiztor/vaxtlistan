<script setup lang="ts">
// Component for displaying a single plant in lager
import type { Totallager, Facit } from '~/types/supabase-tables';
import { ref, computed } from 'vue';
const supabase = useSupabaseClient();
const user = useSupabaseUser();
const { width, height } = useWindowSize();
const props = defineProps<{ plant: Totallager; facit: Facit }>();
const emit = defineEmits(['update']);

// State for editing fields
const modalOpen = ref(false);
const editField = ref<string | null>(null);
const editValue = ref<any>(null);
const loading = ref(false);
const error = ref<string | null>(null);

// Helper: check if user can edit (plantskola owner)
const canEdit = computed(() => {
  // You may want to pass plantskola.user_id as a prop for strict check
  return !!user.value;
});

// Open modal for a field
const openEdit = (field: string, value: any) => {
  modalOpen.value = true;
  editField.value = field;
  editValue.value = value;
  error.value = null;
};

// Close modal
const closeEdit = () => {
  modalOpen.value = false;
  editField.value = null;
  editValue.value = null;
  error.value = null;
};

// Update field in Supabase
type EditableField =
  | 'name_by_plantskola'
  | 'description_by_plantskola'
  | 'pot'
  | 'height'
  | 'price'
  | 'stock';

const updateField = async () => {
  if (!editField.value) return;
  loading.value = true;
  error.value = null;
  const { error: upError } = await supabase
    .from('totallager')
    .update({ [editField.value]: editValue.value, last_edited: new Date().toISOString() })
    .eq('id', props.plant.id);
  loading.value = false;
  if (upError) {
    error.value = upError.message;
    return;
  }
  emit('update', { id: props.plant.id, field: editField.value, value: editValue.value }); // Emit updated info
  closeEdit();
};

// Optionally, you could fetch more facit info if needed
</script>

<template>
  <li class="flex flex-row items-center gap-4 p-2 rounded-lg bg-elevated border-1 border-regular">
    <div class="flex-1">
      <div class="flex items-center gap-2">
        <span class="font-bold text-lg">{{
          facit?.find((item) => item.id === plant.facit_id)!.name
        }}</span>
        <span v-if="plant.name_by_plantskola"> ({{ plant.name_by_plantskola }})</span>
        <UButton
          v-if="canEdit"
          icon="i-heroicons-pencil-square"
          size="xs"
          color="primary"
          variant="ghost"
          @click="openEdit('name_by_plantskola', plant.name_by_plantskola)"
        ></UButton>
      </div>
      <div class="flex items-center gap-2">
        <span v-if="plant.description_by_plantskola"> {{ plant.description_by_plantskola }}</span>
        <UButton
          v-if="canEdit"
          icon="i-heroicons-pencil-square"
          size="xs"
          color="primary"
          variant="ghost"
          @click="openEdit('description_by_plantskola', plant.description_by_plantskola)"
        ></UButton>
        <span>{{ facit?.find((item) => item.id === plant.facit_id)!.sv_name }}</span>
      </div>
      <div class="flex flex-wrap gap-2 mt-1">
        <div class="flex items-center gap-1" v-if="plant.pot">
          <UBadge color="neutral" variant="subtle">Kruka: {{ plant.pot }}</UBadge>
          <UButton
            v-if="canEdit"
            icon="i-heroicons-pencil-square"
            size="xs"
            color="primary"
            variant="ghost"
            @click="openEdit('pot', plant.pot)"
          ></UButton>
        </div>
        <div class="flex items-center gap-1" v-if="plant.height">
          <UBadge color="neutral" variant="subtle">Höjd: {{ plant.height }}</UBadge>
          <UButton
            v-if="canEdit"
            icon="i-heroicons-pencil-square"
            size="xs"
            color="primary"
            variant="ghost"
            @click="openEdit('height', plant.height)"
          ></UButton>
        </div>
        <UBadge color="primary" variant="subtle" v-if="plant.height">{{
          facit.find((item) => item.id === plant.facit_id)!.type
        }}</UBadge>
      </div>
    </div>
    <div class="flex flex-col gap-2 items-end">
      <div class="flex items-center gap-1" v-if="plant.stock !== undefined">
        <UBadge
          :color="plant.stock > 0 ? 'neutral' : 'error'"
          :size="width < 550 ? 'md' : 'xl'"
          variant="subtle"
          >Lager: <span class="font-black">{{ plant.stock }} st</span></UBadge
        >
        <UButton
          v-if="canEdit"
          icon="i-heroicons-pencil-square"
          size="xs"
          color="primary"
          variant="ghost"
          @click="openEdit('stock', plant.stock)"
        ></UButton>
      </div>
      <div class="flex items-center gap-1" v-if="plant.price !== undefined">
        <UBadge color="neutral" :size="width < 550 ? 'md' : 'lg'" variant="subtle">
          <span class="font-black">{{ plant.price }} kr</span>
        </UBadge>
        <UButton
          v-if="canEdit"
          icon="i-heroicons-pencil-square"
          size="xs"
          color="primary"
          variant="ghost"
          @click="openEdit('price', plant.price)"
        ></UButton>
      </div>
    </div>

    <!-- Edit Modal -->
    <!-- :title="'Redigera ' + editField" -->
    <UModal
      v-model:open="modalOpen"
      title="Redigera"
      @close="closeEdit"
      :close="{ onClick: closeEdit }"
      :ui="{
        content: 'p-4',
      }"
    >
      <template #content>
        <form @submit.prevent="updateField" class="flex flex-col gap-4">
          <UInput
            v-model="editValue"
            :label="editField"
            :type="['price', 'stock'].includes(editField) ? 'number' : 'text'"
            required
            autofocus
          />
          <div class="flex gap-2 justify-end">
            <UButton type="button" color="natural" variant="ghost" @click="closeEdit"
              >Avbryt</UButton
            >
            <UButton type="submit" color="primary" :loading="loading">Spara</UButton>
          </div>
          <div v-if="error" class="text-error">{{ error }}</div>
        </form>
      </template>
    </UModal>
  </li>
</template>

<style scoped>
/* Only use Nuxt UI and Tailwind classes */
</style>
