<script setup lang="ts">
import type { RandomPlantWithStock } from '~/composables/useRandomPlants';

interface Props {
  plant: RandomPlantWithStock;
}

const props = defineProps<Props>();

/**
 * Get the first image URL from the plant's images array
 */
const getFirstImageUrl = (images: any[] | null): string | null => {
  if (!images || !Array.isArray(images) || images.length === 0) {
    return null;
  }

  // Images should have a url property based on GoogleImageResult interface
  return images[0]?.url || null;
};

/**
 * Format price range for display
 */
const formatPriceRange = (minPrice: number | null, maxPrice: number | null): string => {
  if (!minPrice && !maxPrice) return 'Kontakta plantskola';

  if (minPrice === maxPrice) {
    return `${minPrice} kr`;
  }

  return `${minPrice || 0} - ${maxPrice || 0} kr`;
};

/**
 * Get the plant's main image URL
 */
const imageUrl = computed(() => getFirstImageUrl(props.plant.images));

/**
 * Get formatted price range
 */
const priceRange = computed(() => formatPriceRange(props.plant.min_price, props.plant.max_price));

/**
 * Get plant display name
 */
</script>

<template>
  <div class="group cursor-pointer h-full">
    <NuxtLink :to="`/vaxt/${plant.id}/${encodeURIComponent(plant.name)}`" class="block h-full">
      <div
        class="bg-bg-elevated border border-border rounded-2xl overflow-hidden h-full flex flex-col"
      >
        <!-- Plant Image -->
        <div class="aspect-square relative overflow-hidden bg-bg-accente">
          <img
            v-if="imageUrl"
            :src="imageUrl"
            :alt="plant.name"
            class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300 rounded-2x"
            loading="lazy"
          />
          <div v-else class="w-full h-full flex items-center justify-center">
            <UIcon name="ph:plant" class="text-6xl text-t-muted" />
          </div>
        </div>

        <!-- Plant Information -->
        <div class="p-4 flex-1 flex flex-col">
          <!-- Plant Name -->
          <div class="mb-2">
            <h3 class="font-semibold text-base sm:text-lg leading-tight hover:underline">
              {{ plant.name }}
            </h3>
            <p
              v-if="plant.sv_name && plant.sv_name !== plant.name"
              class="text-sm text-gray-500 dark:text-gray-400 italic mt-1"
            >
              {{ plant.sv_name }}
            </p>
          </div>

          <!-- Price and Action -->
          <div class="mt-auto">
            <div class="flex items-center justify-start">
              <p class="font-semibold text-primary">
                {{ priceRange }}
              </p>
            </div>
          </div>
        </div>
      </div>
    </NuxtLink>
  </div>
</template>

<style scoped></style>
