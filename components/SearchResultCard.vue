<script setup lang="ts">
import type { AvailablePlantSimilaritySearchResult } from '~/types/supabase-tables';
import { usePlantType } from '~/composables/usePlantType';

const props = defineProps<{
  plant: AvailablePlantSimilaritySearchResult;
  showDetailed?: boolean;
  viewMode?: 'list' | 'grid';
}>();
const supabase = useSupabaseClient();
const { getAllRhsTypeLabels } = usePlantType();

const image = computed(() => {
  if (
    props.plant.lignosdatabasen_images &&
    Array.isArray(props.plant.lignosdatabasen_images) &&
    props.plant.lignosdatabasen_images.length > 0
  ) {
    return props.plant.lignosdatabasen_images[0].replace(
      '/upload/',
      '/upload/t_500bred,f_auto,q_auto/'
    );
  }
  if (props.plant.images && Array.isArray(props.plant.images) && props.plant.images.length > 0) {
    const firstImage = props.plant.images[0];
    if (firstImage && typeof firstImage === 'object' && firstImage.url) {
      return firstImage.url;
    }
  }
});

// Compute the price range for this plant
const priceRange = computed(() => {
  let minPrice: number | null = null;
  let maxPrice: number | null = null;

  // Use min_price and max_price if available (from new search function)
  if (props.plant.min_price !== undefined && props.plant.min_price !== null) {
    minPrice = props.plant.min_price;
    // Check if max_price exists in the plant data
    if (
      'max_price' in props.plant &&
      props.plant.max_price !== undefined &&
      props.plant.max_price !== null
    ) {
      maxPrice = props.plant.max_price;
    } else {
      maxPrice = minPrice; // Fallback to min_price if max_price doesn't exist
    }
  } else if (props.plant.prices && props.plant.prices.length > 0) {
    // Fallback to calculating from prices array for backward compatibility
    let priceValues: number[] = [];

    // Check if prices is array of numbers (old format) or array of objects (new format)
    if (typeof props.plant.prices[0] === 'number') {
      priceValues = props.plant.prices as unknown as number[];
    } else {
      // New format: array of PriceInfo objects
      priceValues = (props.plant.prices as any[])
        .map((priceInfo) => priceInfo.price)
        .filter((price) => price != null);
    }

    if (priceValues.length > 0) {
      minPrice = Math.min(...priceValues);
      maxPrice = Math.max(...priceValues);
    }
  }

  return { min: minPrice, max: maxPrice };
});

// Format price with currency
const formatPrice = (price: number) => {
  return new Intl.NumberFormat('sv-SE', {
    style: 'currency',
    currency: 'SEK',
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  }).format(price);
};

// Format price range display
const formatPriceRange = (range: { min: number | null; max: number | null }) => {
  if (range.min === null || range.max === null) {
    return null;
  }

  // If min and max are the same, show just one price
  if (range.min === range.max) {
    return formatPrice(range.min);
  }

  // Otherwise show the range
  return `${formatPrice(range.min).replace(/\s*kr$/, '')} - ${formatPrice(range.max)}`;
};
</script>

<template>
  <!-- List View -->
  <NuxtLink
    v-if="!viewMode || viewMode === 'list'"
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
      <img v-if="image" :src="image" class="object-cover h-20 w-20 rounded-md aspect-square" />
      <div v-else class="w-20 h-20 bg-bg-elevated rounded-md grid place-items-center">
        <UIcon name="f7:tree" size="30" class="text-t-muted opacity-70" />
      </div>
      <div class="flex-1">
        <div class="font-semibold text-lg">{{ plant.name }}</div>

        <!-- SV name -->
        <div class="text-sm" v-if="plant.sv_name">{{ plant.sv_name }}</div>

        <!-- Detailed information (conditionally shown) -->
        <div v-if="showDetailed" class="flex flex-wrap gap-2 mt-1">
          <!-- Plant type -->
          <UBadge v-if="plant.plant_type" color="neutral" variant="subtle" size="sm">
            <span class="font-semibold">{{ plant.plant_type }}</span>
          </UBadge>

          <!-- RHS types -->
          <UBadge
            v-if="plant.rhs_types && plant.rhs_types.length > 0"
            color="neutral"
            variant="subtle"
            size="sm"
          >
            <span class="font-semibold">{{ getAllRhsTypeLabels(plant.rhs_types).join(', ') }}</span>
          </UBadge>

          <!-- Plant attributes: Height -->
          <UBadge
            v-if="plant.plant_attributes && plant.plant_attributes.height"
            color="neutral"
            variant="subtle"
            size="sm"
          >
            Höjd: <span class="font-semibold">{{ plant.plant_attributes.height }}</span>
          </UBadge>

          <!-- Plant attributes: Spread -->
          <UBadge
            v-if="plant.plant_attributes && plant.plant_attributes.spread"
            color="neutral"
            variant="subtle"
            size="sm"
          >
            Bredd: <span class="font-semibold">{{ plant.plant_attributes.spread }}</span>
          </UBadge>
        </div>

        <!-- Grupp and Serie information -->
        <div class="flex flex-wrap gap-2 mt-1" v-if="plant.grupp || plant.serie">
          <UBadge v-if="plant.grupp" color="neutral" variant="outline" size="sm">
            Grupp: {{ plant.grupp }}
          </UBadge>
          <UBadge v-if="plant.serie" color="neutral" variant="outline" size="sm">
            Serie: {{ plant.serie }}
          </UBadge>
        </div>
        <div
          class="p-2 py-1.5 border border-border rounded-lg mt-2 w-fit flex gap-6 text-xs md:text-sm"
          v-if="priceRange.min !== null"
        >
          <!-- Price information -->
          <div v-if="priceRange.max !== 0">
            <span class="font-semibold">{{ formatPriceRange(priceRange) }}</span>
          </div>
          <div>
            <span v-if="plant.plantskolor_count > 1"
              ><span class="font-semibold">{{ plant.plantskolor_count }}</span> st plantskolor</span
            >
            <span v-else><span class="font-semibold">1</span> plantskola</span>
          </div>
        </div>
      </div>
    </div>
  </NuxtLink>

  <!-- Grid View -->
  <div v-else class="h-full">
    <div class="flex flex-col h-full">
      <!-- Plant image -->
      <NuxtLink
        :to="`/vaxt/${plant.id}/${plant.name
          .toString()
          .toLowerCase()
          .replace(/[^a-z0-9åäö\- ]/gi, '')
          .replace(/\s+/g, '+')
          .replace(/-+/g, '+')
          .replace(/^-+|-+$/g, '')}`"
        class="w-full aspect-[1.618/1] bg-bg-elevated rounded-lg mb-3 overflow-hidden border border-border"
      >
        <img
          v-if="image"
          :src="image"
          :alt="plant.name"
          class="w-full h-full object-cover hover:scale-105 transition-transform duration-200"
          loading="lazy"
        />
        <div v-else class="w-full h-full grid place-items-center">
          <UIcon name="f7:tree" size="40" class="text-t-muted opacity-70" />
        </div>
      </NuxtLink>

      <!-- Plant content -->
      <div class="flex flex-col flex-1">
        <div class="flex gap-2 justify-between items-start">
          <div class="flex-1">
            <!-- Plant name -->
            <div class="">
              <NuxtLink
                :to="`/vaxt/${plant.id}/${plant.name
                  .toString()
                  .toLowerCase()
                  .replace(/[^a-z0-9åäö\- ]/gi, '')
                  .replace(/\s+/g, '+')
                  .replace(/-+/g, '+')
                  .replace(/^-+|-+$/g, '')}`"
                class="text-t-regular hover:underline"
              >
                <h3 class="font-semibold text-base leading-tight">
                  {{ plant.name }}
                </h3>
              </NuxtLink>
            </div>

            <!-- SV name -->
            <p v-if="plant.sv_name" class="text-sm text-t-toned">
              {{ plant.sv_name }}
            </p>
          </div>

          <!-- Price information -->
          <div class="" v-if="priceRange.min !== null">
            <div class="flex flex-col items-end gap-1 text-right">
              <span class="font-bold text-base leading-none" v-if="priceRange.max !== 0">
                {{ formatPriceRange(priceRange) }}
              </span>
              <span class="text-xs" :class="priceRange.max === 0 ? 'mt-0.5' : 'text-t-toned'">
                <span v-if="plant.plantskolor_count > 1">
                  <span class="font-semibold">{{ plant.plantskolor_count }}</span> plantskolor
                </span>
                <span v-else><span class="font-semibold">1</span> plantskola</span>
              </span>
            </div>
          </div>
        </div>
        <!-- Plant type and attributes badges -->
        <div class="flex flex-wrap gap-1 mb-2 mt-1">
          <UBadge
            v-if="plant.plant_type && showDetailed"
            color="neutral"
            variant="soft"
            class="text-xs"
          >
            {{ plant.plant_type }}
          </UBadge>
          <UBadge
            v-if="plant.rhs_types && plant.rhs_types.length > 0 && showDetailed"
            color="neutral"
            variant="soft"
            class="text-xs"
          >
            {{ getAllRhsTypeLabels(plant.rhs_types).join(', ') }}
          </UBadge>
          <UBadge
            v-if="plant.plant_attributes && plant.plant_attributes.height && showDetailed"
            color="neutral"
            variant="soft"
            class="text-xs"
          >
            {{ plant.plant_attributes.height }}
          </UBadge>
          <UBadge
            v-if="plant.plant_attributes && plant.plant_attributes.spread && showDetailed"
            color="neutral"
            variant="soft"
            class="text-xs"
          >
            {{ plant.plant_attributes.spread }}
          </UBadge>

          <UBadge v-if="plant.grupp" color="neutral" variant="soft" class="text-xs">
            Grupp: {{ plant.grupp }}
          </UBadge>
          <UBadge v-if="plant.serie" color="neutral" variant="soft" class="text-xs">
            Serie: {{ plant.serie }}
          </UBadge>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped></style>
