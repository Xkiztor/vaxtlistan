<script setup lang="ts">
// Import Nuxt composables and Supabase client
import type { Facit } from '~/types/supabase-tables';
import { useLignosdatabasen } from '~/stores/lignosdatabasen';
import { computed } from 'vue';

const { width, height } = useWindowSize();

const runtimeConfig = useRuntimeConfig();
const route = useRoute();
const id = computed(() => route.params.id);
const supabase = useSupabaseClient();
const router = useRouter(); // Import Nuxt router

const {
  data: plant,
  status,
  error,
} = await useAsyncData<Facit | null>(
  'plant',
  async () => {
    const { data, error } = await supabase.from('facit').select('*').eq('id', id.value).single();
    if (error) {
      console.error('Error fetching plant data:', error.message);
      throw error;
    }
    if (data && (data as Facit).name && route.params.vaxt !== (data as Facit).name) {
      const slug = (data as Facit).name
        .toString()
        .toLowerCase()
        .replace(/[^a-z0-9åäö\- ]/gi, '')
        .replace(/\s+/g, '+')
        .replace(/-+/g, '+')
        .replace(/^-+|-+$/g, '');
      router.replace({
        name: route.name,
        params: { ...route.params, vaxt: slug },
      });
    }
    // console.log(data);
    return data as Facit | null;
  },
  { watch: [id] }
);

// Use the plant attributes composable
const {
  sunlightLabels,
  soilTypeLabels,
  fullHeightTimeLabels,
  moistureLabels,
  phLabels,
  exposureLabels,
  seasonOfInterestLabels,
  plantTypeLabel,
  colorsBySeason,
  getColorClass,
  getBaseIcon,
  graphicalPlantBySeason,
  getIconColorStyle,
} = usePlantAttributes(plant);

const lignosdatabasen = useLignosdatabasen();
// lignosdatabasen.getLignosdatabasen(runtimeConfig); // Fetch lignosdatabasen data if needed
await useAsyncData('lignosdatabasen', () => lignosdatabasen.getLignosdatabasen(runtimeConfig));
const lignosdatabasenPlant = computed(() => {
  if (!plant.value || !lignosdatabasen.lignosdatabasen) return null;
  return lignosdatabasen.lignosdatabasen.find(
    (lig) =>
      `${lig.slakte?.toLowerCase() || ''}${lig.art?.toLowerCase() || ''}${lig.sortnamn ? "'" : ''}${
        lig.sortnamn ? lig.sortnamn.toLowerCase() : ''
      }${lig.sortnamn ? "'" : ''}`.replace(/\s+/g, '') ===
      plant.value?.name.toLowerCase().replace(/\s+/g, '')
  );
});
const lignosImages = computed(() => {
  if (!lignosdatabasenPlant.value) return null;

  let images = lignosdatabasenPlant.value.text
    ? lignosdatabasenPlant.value.text
        .split(/!\[(?!omslag\])[^]*?\]\(([^)]+)\)/g)
        .filter((str: string) => str !== '' && str.includes('http') && !str.includes('['))
    : [];
  if (images.length && images[0].includes('cloudinary')) {
    return images.map((img: string) =>
      img.replace('/upload/', '/upload/t_1000bred,f_auto,q_auto/')
    );
  } else if (images.length) {
    return images;
  } else {
    return '';
  }
});
const lignosText = () => {
  let desc = lignosdatabasenPlant.value.text;

  desc = desc.replace(/!\[.*?\]\(.*?\)|\[.*?\]\(.*?\)/g, ''); // Remove markdown image and link syntax
  desc = desc.replace(/[*\-_#{}\[\]]/g, ''); // Remove markdown formatting characters
  desc = desc.replace(/::\w+/g, ''); // Remove ::Fify
  desc = desc.replace(/::/g, ''); // Remove ::

  return desc;
};

const overlay = useOverlay();
import ImageViewer from '~/components/ImageViewer.vue';
const imageModal = overlay.create(ImageViewer);

function openImage(s: string) {
  imageModal.open({
    src: s.replace('/t_1000bred', '/t_2000bred'),
  });
}

// watchEffect(() => {
//   // When plant is loaded and name is available
//   if (plant.value && plant.value.name && route.params.vaxt !== plant.value.name) {
//     // Replace the [vaxt] part of the URL with the plant's name (slugified for safety)

//   }
// });
</script>

<template>
  <div class="max-w-3xl mx-auto">
    <!-- Loading state -->
    <div v-if="status === 'pending'" class="pt-4">Laddar...</div>

    <!-- Error state -->
    <div v-else-if="error">
      <div class="bg-error text-inverted p-4 rounded-md mt-4">
        <p class="text-xl font-bold">Växten hittades inte</p>
        <div class="flex items-center gap-2">
          <UIcon name="i-heroicons-exclamation-triangle" size="20" />
          {{ error }}
        </div>
      </div>
      <UButton class="mt-4" to="/vaxt/s/" icon="i-heroicons-magnifying-glass"
        >Återvänd till sök</UButton
      >
    </div>

    <!-- Plant details -->
    <div v-else-if="plant" class="p-6">
      <div v-if="lignosImages" class="mb-6">
        <UCarousel
          v-slot="{ item }"
          dots
          :arrows="width > 768"
          :items="lignosImages"
          class="w-full mx-auto rounded-md"
          :ui="{
            // container: 'transition-[height]',
            // controls: ',
            item: 'md:basis-1/3',
            dots: 'absolute opacity-70 -translate-y-2',
            // dot: 'bg-white',
          }"
        >
          <NuxtImg
            :src="item as string"
            @click="openImage(item as string)"
            class="rounded-lg aspect-square object-cover h-full w-full"
          />
        </UCarousel>
      </div>
      <h1 class="text-3xl font-bold mb-1">{{ plant.name }}</h1>
      <p class="mb-6 italic text-lg" v-if="plant.sv_name">{{ plant.sv_name }}</p>

      <div class="flex flex-col gap-4">
        <!-- Plant Type -->
        <div class="flex flex-wrap items-center gap-4">
          <div v-if="plantTypeLabel" class="flex flex-wrap items-center gap-2">
            <span class="font-semibold">Typ:</span>
            <UBadge color="primary" size="lg" variant="soft">
              {{ plantTypeLabel }}
            </UBadge>
          </div>

          <!-- Size Information -->
          <div v-if="plant.height" class="flex items-center gap-2">
            <span class="font-semibold">Höjd:</span>
            <UBadge color="neutral" size="lg" variant="soft">
              {{ plant.height }}
            </UBadge>
          </div>
          <div v-if="plant.spread" class="flex items-center gap-2">
            <span class="font-semibold">Bredd:</span>
            <UBadge color="neutral" size="lg" variant="soft">
              {{ plant.spread }}
            </UBadge>
          </div>
          <div v-if="fullHeightTimeLabels" class="flex items-center gap-2">
            <span class="font-semibold">Tid till fullväxt:</span>
            <UBadge color="neutral" size="lg" variant="soft">
              {{ fullHeightTimeLabels }}
            </UBadge>
          </div>
        </div>

        <div v-if="lignosdatabasenPlant">
          <div class="prose max-w-none" v-html="lignosText()"></div>
          <div class="mt-1">
            <UButton
              :href="`https://lignosdatabasen.se/planta/${lignosdatabasenPlant.slakte}/${
                lignosdatabasenPlant.art
              }${
                lignosdatabasenPlant.sortnamn
                  ? `/${lignosdatabasenPlant.sortnamn.replace(`'`, '')}`
                  : ''
              }`"
              target="_blank"
              rel="noopener noreferrer"
              color="primary"
              icon="i-heroicons-arrow-top-right-on-square"
              variant="link"
              class="p-0"
            >
              Läs mer i Lignosdatabasen
            </UButton>
          </div>
        </div>

        <!-- Growing Conditions -->
        <div class="space-y-2 mb-4">
          <h3 class="text-xl font-semibold">Odlingsförhållanden</h3>
          <div class="grid gap-2 md:grid-cols-2 md:gap-16">
            <div class="flex gap-2 w-full justify-between">
              <div v-if="sunlightLabels" class="flex flex-col gap-2">
                <span class="font-bold">Ljus</span>
                <div>
                  <div class="flex gap-2">
                    <UIcon
                      v-for="(label, idx) in sunlightLabels.split(' / ')"
                      :key="idx"
                      :name="
                        label.trim() === 'Soligt'
                          ? 'material-symbols:clear-day-rounded'
                          : label.trim() === 'Delvis skuggigt'
                          ? 'meteocons:partly-cloudy-day-fill'
                          : label.trim() === 'Helt skuggigt'
                          ? 'meteocons:cloudy-fill'
                          : 'mdi:help-circle-outline'
                      "
                      class="w-8 h-8"
                      :class="{
                        'text-info': label.trim() === 'Soligt',
                        'h-12 w-12': label.trim() !== 'Soligt',
                      }"
                      :title="label.trim()"
                    />
                  </div>
                </div>
              </div>
              <div v-if="exposureLabels" class="flex flex-col gap-2">
                <span class="font-bold">Exponering</span>
                <span>{{ exposureLabels }}</span>
              </div>
            </div>

            <div class="flex flex-col gap-2">
              <div v-if="soilTypeLabels" class="flex flex-col gap-2 w-full">
                <span class="font-bold">Jord</span>
                <span>{{ soilTypeLabels }}</span>
              </div>
              <div>
                <div class="flex items-center gap-2 w-full justify-between flex-wrap">
                  <span v-if="phLabels">
                    <span class="font-medium inline">{{ phLabels ? 'pH:' : '' }}</span>
                    {{ phLabels }}</span
                  >
                  <span v-if="moistureLabels" class="flex flex-col gap-2">
                    {{ moistureLabels }}
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>
        <!-- Seasonal Interest and Colors -->
        <div class="mb-4 space-y-4">
          <h3 class="text-xl font-semibold">Utseende och säsong</h3>

          <!-- General seasonal interest -->
          <div v-if="seasonOfInterestLabels" class="flex items-center gap-2">
            <span class="font-medium">Säsong av intresse:</span>
            <UBadge color="success" size="lg" variant="soft">
              {{ seasonOfInterestLabels }}
            </UBadge>
          </div>
          <!-- Graphical plant representation by season -->
          <div v-if="graphicalPlantBySeason" class="space-y-3">
            <!-- Graphical timeline -->
            <div class="relative pt-4">
              <!-- Timeline line -->
              <div class="absolute bottom-9 left-0 right-0 h-0.5 bg-border"></div>

              <!-- Season markers and plant representations -->
              <div class="grid grid-cols-4 gap-4">
                <div
                  v-for="(season, seasonId) in graphicalPlantBySeason"
                  :key="seasonId"
                  class="relative grid place-items-center gap-2 h-full"
                >
                  <!-- Plant representation -->
                  <div
                    v-if="
                      season.plant.foliage.length > 0 ||
                      season.plant.stem.length > 0 ||
                      season.plant.fruit.length > 0 ||
                      season.plant.flower.length > 0
                    "
                    class="relative flex flex-col items-center justify-center h-16"
                  >
                    <!-- Base plant icon (tree/leaves) with foliage colors -->
                    <div class="relative z-10">
                      <GradientIcon
                        v-if="season.plant.foliage.length > 0"
                        :icon-name="getBaseIcon"
                        icon-class="w-12 h-12"
                        :icon-style="getIconColorStyle(season.plant.foliage).style"
                        :use-gradient="getIconColorStyle(season.plant.foliage).useGradient"
                        :gradient-colors="getIconColorStyle(season.plant.foliage).gradientColors"
                        :gradient-id="getIconColorStyle(season.plant.foliage).gradientId"
                      />
                      <UIcon v-else :name="getBaseIcon" class="w-12 h-12 text-t-muted opacity-10" />
                    </div>
                    <!-- Flower overlay (top-left) -->
                    <div v-if="season.plant.flower.length > 0" class="absolute -top-1 -left-4 z-20">
                      <UTooltip
                        :text="`Blomma: ${season.plant.flower.map((f: any) => f.colorName).join(', ')}`"
                        :popper="{ placement: 'top' }"
                        :delay-duration="0"
                      >
                        <GradientIcon
                          icon-name="famicons:flower"
                          icon-class="w-6 h-6 cursor-help"
                          :icon-style="getIconColorStyle(season.plant.flower).style"
                          :use-gradient="getIconColorStyle(season.plant.flower).useGradient"
                          :gradient-colors="getIconColorStyle(season.plant.flower).gradientColors"
                          :gradient-id="getIconColorStyle(season.plant.flower).gradientId"
                        />
                      </UTooltip>
                    </div>
                    <!-- Fruit overlay (top-right) -->
                    <div v-if="season.plant.fruit.length > 0" class="absolute -top-1 -right-4 z-20">
                      <UTooltip
                        :text="`Frukt: ${season.plant.fruit.map((f: any) => f.colorName).join(', ')}`"
                        :popper="{ placement: 'top' }"
                        :delay-duration="0"
                      >
                        <GradientIcon
                          icon-name="tabler:apple-filled"
                          icon-class="w-6 h-6 cursor-help"
                          :icon-style="getIconColorStyle(season.plant.fruit).style"
                          :use-gradient="getIconColorStyle(season.plant.fruit).useGradient"
                          :gradient-colors="getIconColorStyle(season.plant.fruit).gradientColors"
                          :gradient-id="getIconColorStyle(season.plant.fruit).gradientId"
                        />
                      </UTooltip>
                    </div>
                    <!-- Stem (above main icon) -->
                    <div v-if="season.plant.stem.length > 0" class="absolute -top-5 z-5">
                      <UTooltip
                        :text="`Stam: ${season.plant.stem.map((s: any) => s.colorName).join(', ')}`"
                        :popper="{ placement: 'bottom' }"
                        :delay-duration="0"
                      >
                        <GradientIcon
                          icon-name="game-icons:birch-trees"
                          icon-class="w-6 h-6 cursor-help"
                          :icon-style="getIconColorStyle(season.plant.stem).style"
                          :use-gradient="getIconColorStyle(season.plant.stem).useGradient"
                          :gradient-colors="getIconColorStyle(season.plant.stem).gradientColors"
                          :gradient-id="getIconColorStyle(season.plant.stem).gradientId"
                        />
                      </UTooltip>
                    </div>

                    <!-- Foliage tooltip for main icon -->
                    <UTooltip
                      v-if="season.plant.foliage.length > 0"
                      :text="`Bladverket: ${season.plant.foliage.map((f: any) => f.colorName).join(', ')}`"
                      :popper="{ placement: 'top' }"
                      :delay-duration="0"
                    >
                      <div class="absolute inset-0 cursor-help z-15"></div>
                    </UTooltip>
                  </div>

                  <!-- Empty state -->
                  <div v-else class="h-24 flex items-center justify-center">
                    <UIcon :name="getBaseIcon" class="w-12 h-12 text-t-muted opacity-10" />
                  </div>

                  <!-- Season name at bottom -->
                  <div class="text-sm font-medium">{{ season.name }}</div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
/* Add any custom styles if needed */
</style>
