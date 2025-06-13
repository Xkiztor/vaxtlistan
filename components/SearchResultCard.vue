<script setup lang="ts">
import type { Facit } from '~/types/supabase-tables';
import { usePlantType } from '~/composables/usePlantType';

const props = defineProps<{ plant: Facit }>();
const supabase = useSupabaseClient();
const { getRhsTypeLabel, getAllRhsTypeLabels } = usePlantType();

const lignosdatabasen = useLignosdatabasen();
const facitStore = useFacitStore();

const lignosdatabasenPlant = computed(() => {
  return lignosdatabasen.lignosdatabasen?.find(
    (lig) =>
      `${lig.slakte.toLowerCase()}${lig.art.toLowerCase()}${lig.sortnamn ? "'" : ''}${
        lig.sortnamn ? lig.sortnamn.toLowerCase() : ''
      }${lig.sortnamn ? "'" : ''}`.replace(/\s+/g, '') ===
      props.plant.name.toLowerCase().replace(/\s+/g, '')
  );
});

const image = computed(() => {
  if (!lignosdatabasenPlant.value) return null;
  let images = lignosdatabasenPlant.value?.text
    .split(/!\[[^\]]*\]\(([^)]+)\)/g)
    .filter((str: string) => str !== '' && str.includes('http') && !str.includes('['));

  if (images.length && images[0].includes('cloudinary')) {
    return images[0].replace('/upload/', '/upload/t_500bred,f_auto,q_auto/');
  } else if (images.length) {
    return images[0];
  } else {
    return '';
  }
});
</script>

<template>
  <NuxtLink
    class="rounded-xl cursor-pointer"
    :to="`/vaxt/${plant.id}/${plant.name
      .toString()
      .toLowerCase()
      .replace(/[^a-z0-9åäö\- ]/gi, '')
      .replace(/\s+/g, '+')
      .replace(/-+/g, '+')
      .replace(/^-+|-+$/g, '')}`"
  >
    <div class="flex items-center gap-4 mb-2">
      <!-- Placeholder avatar, replace with image if available -->
      <NuxtImg v-if="image" :src="image" class="object-cover h-20 w-20 rounded-md aspect-square" />
      <div v-else class="w-20 h-20 bg-bg-elevated rounded-md grid place-items-center">
        <UIcon name="f7:tree" size="30" class="text-t-muted opacity-70" />
      </div>
      <div class="flex-1">
        <div class="font-semibold text-lg">{{ plant.name }}</div>

        <!-- SV name -->
        <div class="text-sm" v-if="plant.sv_name">{{ plant.sv_name }}</div>

        <!-- Synonym badge and information -->
        <div v-if="plant.is_synonym" class="mt-2 flex items-center gap-2">
          <UBadge color="neutral" variant="soft" class="text-t-toned"
            >Synonym{{ plant.synonym_to ? ' till ' : '' }}{{ plant.synonym_to }}</UBadge
          >
        </div>
        <!-- Plant attributes -->
        <div class="flex flex-wrap gap-2 mt-2">
          <template v-for="label in getAllRhsTypeLabels(plant.rhs_types)" :key="label">
            <UBadge color="primary" variant="soft">{{ label }}</UBadge>
          </template>
          <UBadge v-if="plant.height" color="neutral" variant="soft"
            >Höjd: {{ plant.height }}</UBadge
          >
          <UBadge v-if="plant.spread" color="neutral" variant="soft"
            >Bredd: {{ plant.spread }}</UBadge
          >
        </div>
      </div>
    </div>
  </NuxtLink>
</template>

<style scoped></style>
