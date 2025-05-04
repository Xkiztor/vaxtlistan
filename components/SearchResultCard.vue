<script setup lang="ts">
import type { FacitFuse } from '~/types/supabase-tables';
// Accept a plant prop (the plant object from search result)
const props = defineProps<{ plant: FacitFuse }>();

const lignosdatabasen = useLignosdatabasen(); // Import lignosdatabasen if needed
const lignosdatabasenPlant = computed(() => {
  return lignosdatabasen.lignosdatabasen?.find(
    (lig) =>
      `${lig.slakte.toLowerCase()}${lig.art.toLowerCase()}${lig.sortnamn ? "'" : ''}${
        lig.sortnamn ? lig.sortnamn.toLowerCase() : ''
      }${lig.sortnamn ? "'" : ''}`.replace(/\s+/g, '') ===
      props.plant.item.name.toLowerCase().replace(/\s+/g, '')
  );
  // return lignosdatabasen.lignosdatabasen;
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
  // return specificPlant.value.text.split(/[\[\]]/).filter(str => str !== '' && str.includes('http'))
});
</script>

<template>
  <NuxtLink
    class="rounded-xl cursor-pointer"
    :to="`/vaxt/${plant.item.id}/${plant.item.name
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
      <div v-else class="w-20 h-20 bg-elevated rounded-md grid place-items-center">
        <UIcon name="f7:tree" size="20" class="text-muted" />
      </div>
      <div>
        <div class="font-semibold text-lg">{{ plant.item.name }}</div>
        <div class="text-muted text-sm" v-if="plant.item.sv_name">{{ plant.item.sv_name }}</div>
        <div class="flex flex-wrap gap-2 mt-2">
          <UBadge v-if="plant.item.type" color="primary" variant="soft">{{
            plant.item.type
          }}</UBadge>
          <UBadge v-if="plant.item.edible" color="primary" variant="soft">Ätlig</UBadge>
          <UBadge v-if="plant.item.zone" color="neutral" variant="soft"
            >Zon {{ plant.item.zone }}</UBadge
          >
          <UBadge v-if="plant.item.max_height" color="secondary" variant="soft"
            >Höjd: {{ plant.item.max_height }} cm</UBadge
          >
          <UBadge v-if="plant.item.max_width" color="secondary" variant="soft"
            >Bredd: {{ plant.item.max_width }} cm</UBadge
          >
        </div>
      </div>
    </div>
  </NuxtLink>
</template>

<style scoped></style>
