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
    if (error) throw error;
    if (error) {
      console.error('Error fetching plant data:', error.message);
    }
    if (data && data.name && route.params.vaxt !== data.name) {
      const slug = data.name
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
      plant.value.name.toLowerCase().replace(/\s+/g, '')
  );
});
const lignosImages = computed(() => {
  if (!lignosdatabasenPlant.value) return null;

  let images = lignosdatabasenPlant.value.text
    ? lignosdatabasenPlant.value.text
        .split(/!\[(?!omslag\])[^]*?\]\(([^)]+)\)/g)
        .filter((str) => str !== '' && str.includes('http') && !str.includes('['))
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

function openImage(s) {
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
    <div v-if="status === 'pending'" class="pt-4">
      <USkeleton class="h-8 w-full mb-2" />
      <USkeleton class="h-6 w-1/2 mb-4" />
      <USkeleton class="h-6 w-1/3 mb-2" />
      <USkeleton class="h-6 w-1/4 mb-2" />
    </div>

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
            :src="item"
            @click="openImage(item)"
            class="rounded-lg aspect-square object-cover h-full w-full"
          />
        </UCarousel>
      </div>
      <h1 class="text-2xl font-bold mb-2">{{ plant.name }}</h1>
      <p class="mb-4 italic" v-if="plant.sv_name">{{ plant.sv_name }}</p>
      <div class="flex flex-col md:flex-row md:gap-6 items-start">
        <div class="mb-2">
          <span class="font-semibold">Typ: </span>
          <UBadge color="primary" size="lg" variant="soft">
            {{
              plant.type === 'P'
                ? 'Träd'
                : plant.type === 'B'
                ? 'Barrträd'
                : plant.type === 'G'
                ? 'Gräs'
                : plant.type === 'O'
                ? 'Ormbunke'
                : plant.type === 'K'
                ? 'Klätterväxt'
                : plant.type === 'P'
                ? 'Perenn'
                : ''
            }}
          </UBadge>
        </div>
        <div class="mb-2" v-if="plant.edible !== null">
          <span class="font-semibold">Ätlig: </span>
          <UBadge :color="plant.edible ? 'green' : 'error'" size="lg" variant="soft">
            {{ plant.edible ? 'Ja' : 'Nej' }}
          </UBadge>
        </div>
        <div class="mb-2" v-if="plant.zone">
          <span class="font-semibold">Zon:</span>
          <UBadge color="primary" variant="soft">{{ plant.zone }}</UBadge>
        </div>
      </div>
      <div v-if="lignosdatabasenPlant">
        <div class="prose max-w-none" v-html="lignosText()"></div>
      </div>
    </div>
  </div>
</template>

<style scoped>
/* Add any custom styles if needed */
</style>
