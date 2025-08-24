<script setup lang="ts">
// Import Nuxt composables and Supabase client
import type { Facit } from '~/types/supabase-tables';
import { useLignosdatabasen } from '~/stores/lignosdatabasen';
import { computed, ref } from 'vue';

// Function to copy text to clipboard
const copyToClipboard = async (text: string) => {
  try {
    await navigator.clipboard.writeText(text);
    // Show success notification
    const toast = useToast();
    toast.add({
      title: 'Kopierat!',
      description: `${text} har kopierats till urklipp`,
      color: 'success',
    });
  } catch (error) {
    console.error('Failed to copy to clipboard:', error);
    // Fallback for older browsers
    const textArea = document.createElement('textarea');
    textArea.value = text;
    document.body.appendChild(textArea);
    textArea.select();
    document.execCommand('copy');
    document.body.removeChild(textArea);

    const toast = useToast();
    toast.add({
      title: 'Kopierat!',
      description: `${text} har kopierats till urklipp`,
      color: 'success',
    });
  }
};

// Interface for stock data with nursery information
interface PlantStock {
  id: number;
  stock: number;
  price: number | null;
  pot: string | null;
  height: string | null;
  name_by_plantskola: string;
  comment_by_plantskola: string | null;
  last_edited: string;
  plantskola_id: number;
  nursery_name: string;
  nursery_address: string | null;
  nursery_email: string | null;
  nursery_phone: string | null;
  nursery_url: string | null;
  nursery_postorder: boolean;
  nursery_on_site: boolean;
}

const { width, height } = useWindowSize();

const runtimeConfig = useRuntimeConfig();
const route = useRoute();
const id = computed(() => route.params.id);
const supabase = useSupabaseClient();
const router = useRouter(); // Import Nuxt router
const { trackPlantView } = useAnalytics(); // Add analytics composable

const {
  data: plant,
  status,
  error,
} = await useAsyncData<Facit | null>(
  `plant-${id.value}`,
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
  { lazy: true }
);

// Fetch stock data for this plant from nurseries
const {
  data: stockData,
  status: statusStock,
  error: errorStock,
} = await useAsyncData<PlantStock[]>(
  `plant-stock-${id.value}`,
  async () => {
    // if (!plant.value?.id) return [];
    const { data, error } = await supabase
      .from('totallager')
      .select(
        `
        id,
        stock,
        price,
        pot,
        height,
        name_by_plantskola,
        comment_by_plantskola,
        last_edited,        plantskolor:plantskola_id!inner (
          id,
          name,
          adress,
          email,
          phone,
          url,
          postorder,
          on_site
        )
      `
      )
      .eq('facit_id', id.value)
      .eq('hidden', false)
      .eq('plantskolor.verified', true)
      .gt('stock', 0)
      .order('stock', { ascending: false });
    if (error) {
      console.error('Error fetching stock data:', error.message);
      throw error;
    } // Transform the data to include nursery information at the top level
    return (data || []).map((item: any) => ({
      id: item.id,
      stock: item.stock,
      price: item.price,
      pot: item.pot,
      height: item.height,
      name_by_plantskola: item.name_by_plantskola,
      comment_by_plantskola: item.comment_by_plantskola,
      last_edited: item.last_edited,
      plantskola_id: item.plantskolor?.id || 0,
      nursery_name: item.plantskolor?.name || 'Okänd plantskola',
      nursery_address: item.plantskolor?.adress || null,
      nursery_email: item.plantskolor?.email || null,
      nursery_phone: item.plantskolor?.phone || null,
      nursery_url: item.plantskolor?.url || null,
      nursery_postorder: item.plantskolor?.postorder || false,
      nursery_on_site: item.plantskolor?.on_site || false,
    })) as PlantStock[];
  },
  {
    default: () => [],
    lazy: true,
  }
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
  rhsTypeLabels,
  colorsBySeason,
  getColorClass,
  getBaseIcon,
  graphicalPlantBySeason,
  getIconColorStyle,
} = usePlantAttributes(plant);

// Function to format date for display
const formatDate = (dateString: string) => {
  return new Date(dateString).toLocaleDateString('sv-SE', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });
};

const lignosdatabasen = useLignosdatabasen();
// lignosdatabasen.getLignosdatabasen(runtimeConfig); // Fetch lignosdatabasen data if needed
await useAsyncData(
  `lignosdatabasen-${id.value}`,
  async () => {
    await lignosdatabasen.getLignosdatabasen(runtimeConfig);
  },
  { lazy: true }
);
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
      img.replace('/upload/', '/upload/t_1000bred/f_auto/q_auto/')
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
  desc = desc.replace(/text=".*?"/g, ''); // Remove any text="..." attributes
  desc = desc.replace(/[*\-_#{}\[\]]/g, ''); // Remove markdown formatting characters
  desc = desc.replace(/::\w+/g, ''); // Remove ::Fify
  desc = desc.replace(/::/g, ''); // Remove ::

  return desc;
};

// Image viewer state
const isImageViewerOpen = ref(false);
const currentImageIndex = ref(0);
const currentImages = ref<{ src: string; alt: string; sourcePage?: string; title?: string }[]>([]);

/**
 * Open image viewer with specified images and index
 */
const openImageViewer = (
  images: { src: string; alt: string; sourcePage?: string; title?: string }[],
  index: number = 0
) => {
  currentImages.value = images;
  currentImageIndex.value = index;
  isImageViewerOpen.value = true;
};

/**
 * Close image viewer
 */
const closeImageViewer = () => {
  isImageViewerOpen.value = false;
};

/**
 * Update current image index in viewer
 */
const updateImageIndex = (index: number) => {
  currentImageIndex.value = index;
};

/**
 * Open Lignos image in viewer
 */
const openLignosImage = (imageUrl: string, index: number) => {
  if (!lignosImages.value) return;

  // Create full images array with high resolution and Lignosdatabasen source
  const allImages = lignosImages.value.map((img: string, idx: number) => ({
    src: img.replace('/t_1000bred', '/t_2000bred'), // Higher resolution for viewer
    alt: `${plant.value?.name || 'Växt'} - Bild ${idx + 1}`,
    sourcePage: `https://lignosdatabasen.se/planta/${lignosdatabasenPlant.value?.slakte}/${
      lignosdatabasenPlant.value?.art
    }${
      lignosdatabasenPlant.value?.sortnamn
        ? `/${lignosdatabasenPlant.value.sortnamn.replace(`'`, '')}`
        : ''
    }`,
    title: 'Lignosdatabasen',
  }));

  // Reorder array so clicked image comes first
  const reorderedImages = [
    ...allImages.slice(index), // From clicked image to end
    ...allImages.slice(0, index), // From start to clicked image
  ];

  openImageViewer(reorderedImages, 0); // Always start at index 0 since clicked image is now first
};

/**
 * Open Google image in viewer
 */
const openGoogleImage = (imageUrl: string, index: number) => {
  if (!googleImages.value || !Array.isArray(googleImages.value)) return;

  // Create full images array with Google source information
  const allImages = googleImages.value.map((img: any, idx: number) => ({
    src: img.url,
    alt: img.title || `${plant.value?.name || 'Växt'} - Bild ${idx + 1}`,
    sourcePage: img.sourcePage,
    title: img.title,
  }));

  // Reorder array so clicked image comes first
  const reorderedImages = [
    ...allImages.slice(index), // From clicked image to end
    ...allImages.slice(0, index), // From start to clicked image
  ];

  openImageViewer(reorderedImages, 0); // Always start at index 0 since clicked image is now first
};

/**
 * Open database image in viewer
 */
const openDatabaseImage = (imageUrl: string, index: number) => {
  if (!finalImages.value || !Array.isArray(finalImages.value)) return;

  // Create full images array with database source information
  const allImages = finalImages.value.map((img: any, idx: number) => ({
    src: img.url,
    alt: img.title || `${plant.value?.name || 'Växt'} - Bild ${idx + 1}`,
    sourcePage: img.sourcePage,
    title: img.title,
  }));

  // Reorder array so clicked image comes first
  const reorderedImages = [
    ...allImages.slice(index), // From clicked image to end
    ...allImages.slice(0, index), // From start to clicked image
  ];

  openImageViewer(reorderedImages, 0); // Always start at index 0 since clicked image is now first
};

// Generate structured data for SEO
const structuredData = computed(() => {
  if (!plant.value) return null;

  const offers =
    stockData.value?.map((stock) => ({
      '@type': 'Offer',
      price: stock.price || 0,
      priceCurrency: 'SEK',
      availability:
        stock.stock > 0 ? 'https://schema.org/InStock' : 'https://schema.org/OutOfStock',
      seller: {
        '@type': 'Organization',
        name: stock.nursery_name,
        address: stock.nursery_address || undefined,
        email: stock.nursery_email || undefined,
        telephone: stock.nursery_phone || undefined,
      },
      itemCondition: 'https://schema.org/NewCondition',
    })) || [];

  return {
    '@context': 'https://schema.org',
    '@type': 'Product',
    name: plant.value.name,
    alternateName: plant.value.sv_name || undefined,
    description: lignosdatabasenPlant.value
      ? lignosText()
      : `Information om växten ${plant.value.name}`,
    category: 'Plants & Flowers',
    image: lignosImages.value?.[0] || undefined,
    offers: offers.length > 0 ? offers : undefined,
    brand: {
      '@type': 'Brand',
      name: 'Växtlistan',
    },
    additionalProperty: [
      plant.value.height && {
        '@type': 'PropertyValue',
        name: 'Höjd',
        value: plant.value.height,
      },
      plant.value.spread && {
        '@type': 'PropertyValue',
        name: 'Bredd',
        value: plant.value.spread,
      },
    ].filter(Boolean),
  };
});

// Set page meta for SEO
useHead({
  title: () =>
    plant.value
      ? `${plant.value.name}${plant.value.sv_name ? ` (${plant.value.sv_name})` : ''} - Växtlistan`
      : 'Laddar...',
  meta: [
    {
      name: 'description',
      content: () =>
        plant.value
          ? `Information om ${plant.value.name}${
              plant.value.sv_name ? ` (${plant.value.sv_name})` : ''
            }. ${
              stockData.value?.length
                ? `Finns hos ${stockData.value.length} plantskolor.`
                : 'Ej tillgänglig för närvarande.'
            }`
          : 'Laddar växtinformation...',
    },
    {
      property: 'og:title',
      content: () => (plant.value ? `${plant.value.name} - Växtlistan` : 'Laddar...'),
    },
    {
      property: 'og:description',
      content: () =>
        plant.value
          ? `Information om ${plant.value.name}${
              plant.value.sv_name ? ` (${plant.value.sv_name})` : ''
            }. ${
              stockData.value?.length
                ? `Finns hos ${stockData.value.length} plantskolor.`
                : 'Ej tillgänglig för närvarande.'
            }`
          : 'Laddar växtinformation...',
    },
    {
      property: 'og:image',
      content: () => lignosImages.value?.[0] || '/favicon.ico',
    },
    {
      property: 'og:type',
      content: 'website',
    },
  ],
  script: [
    {
      type: 'application/ld+json',
      innerHTML: () => (structuredData.value ? JSON.stringify(structuredData.value) : ''),
    },
  ],
});

// Group stock data by nursery for display
const groupedStockData = computed(() => {
  if (!stockData.value) return [];
  // Use a unique key for each nursery (preferably id, fallback to name)
  const groups: Record<
    string,
    {
      nursery: Omit<
        PlantStock,
        | 'id'
        | 'stock'
        | 'price'
        | 'pot'
        | 'height'
        | 'name_by_plantskola'
        | 'comment_by_plantskola'
        | 'last_edited'
      > & { nursery_name: string };
      plants: PlantStock[];
    }
  > = {};
  for (const stock of stockData.value) {
    // Create a unique key for the nursery
    const key = `${stock.nursery_name}|${stock.nursery_address || ''}|${stock.nursery_email || ''}`;
    if (!groups[key]) {
      groups[key] = {
        nursery: {
          plantskola_id: stock.plantskola_id,
          nursery_name: stock.nursery_name,
          nursery_address: stock.nursery_address,
          nursery_email: stock.nursery_email,
          nursery_phone: stock.nursery_phone,
          nursery_url: stock.nursery_url,
          nursery_postorder: stock.nursery_postorder,
          nursery_on_site: stock.nursery_on_site,
        },
        plants: [],
      };
    }
    groups[key].plants.push(stock);
  }
  return Object.values(groups);
});

// Check for images from database first, then fetch from Google API if needed
const databaseImages = computed(() => {
  if (!plant.value?.images || !Array.isArray(plant.value.images)) {
    return null;
  }
  return plant.value.images;
});

// Function to save Google photos to database
const saveGoogleImagesToDatabase = async (
  photos: {
    url: string;
    title: string;
    thumbnail: string;
    sourcePage: string;
  }[]
) => {
  if (!plant.value?.id) return;

  try {
    const photosToSave = photos.map((photo) => ({
      url: photo.url,
      title: photo.title,
      sourcePage: photo.sourcePage,
    }));

    const updateData = {
      images: photosToSave,
      images_reordered: false,
      images_added_date: new Date().toISOString(),
    };

    // First, let's try just updating the images field to see if that's the issue
    const { data, error } = await (supabase as any)
      .from('facit')
      .update(updateData)
      .eq('id', plant.value.id)
      .select();

    if (error) {
      console.error('Error saving Google photos to database:', error);
    } else {
      console.log('Successfully saved Google photos to database');
    }
  } catch (error) {
    console.error('Error in saveGoogleImagesToDatabase:', error);
  }
};

// Fetch Google image search results if no database images and no Lignosdatabasen images
const {
  data: googleImages,
  error: googleImagesError,
  pending: googleImagesPending,
  refresh: refreshGoogleImages,
} = await useFetch<{ url: string; title: string; thumbnail: string; sourcePage: string }[]>(
  () => {
    // Only fetch if no database images and no Lignos images
    if (databaseImages.value && databaseImages.value.length > 0) {
      return null; // Don't fetch if we have database images
    }
    if (lignosImages.value && lignosImages.value.length > 0) {
      return null; // Don't fetch if we have Lignos images
    }
    if (!plant.value?.name) {
      return null; // Don't fetch if no plant name
    }
    return `/api/image-search?q=${encodeURIComponent(plant.value.name)}`;
  },
  {
    server: false, // Client-side only to avoid blocking SSR
    immediate: false, // Don't fetch immediately, wait for onMounted
    lazy: true, // Enable lazy loading
    watch: [() => plant.value?.name, () => lignosImages.value, () => databaseImages.value],
    default: () => [],
    onRequestError: (err) => {
      console.error('Error fetching Google images:', err);
    },
    onResponse: async ({ response }) => {
      // Save fetched Google images to database
      if (response._data && Array.isArray(response._data) && response._data.length > 0) {
        await saveGoogleImagesToDatabase(response._data);
      }
    },
  }
);

// Combined images: prioritize database images, then Lignos images, then Google images
const finalImages = computed(() => {
  if (databaseImages.value && databaseImages.value.length > 0) {
    return databaseImages.value.map((img, idx) => ({
      url: img.url,
      title: img.title,
      sourcePage: img.sourcePage,
      source: 'database' as const,
    }));
  }
  return null;
});

// Helper functions for Google images lazy loading and preloading
const shouldPreloadGoogleImage = (index: number) => {
  // Eagerly load first 2 images on mobile, 3 on desktop
  const preloadCount = width.value > 768 ? 3 : 2;
  return index < preloadCount;
};

const getGoogleImagesToPreload = () => {
  if (!googleImages.value || !Array.isArray(googleImages.value)) return [];

  // Preload next 2-3 images after the initially loaded ones for smooth carousel navigation
  const preloadCount = width.value > 768 ? 3 : 2;
  const startIndex = preloadCount;
  const endIndex = Math.min(startIndex + preloadCount, googleImages.value.length);

  return googleImages.value.slice(startIndex, endIndex);
};

// Track plant page view for popularity analytics
onMounted(async () => {
  // Trigger Google image search after page load if needed
  if (
    plant.value?.name &&
    (!databaseImages.value || databaseImages.value.length === 0) &&
    (!lignosImages.value || lignosImages.value.length === 0)
  ) {
    // Use nextTick to ensure the page is fully rendered first
    await nextTick();
    // Refresh the Google images fetch
    await refreshGoogleImages();
  }

  if (plant.value?.id) {
    // Track the page view asynchronously - don't await to avoid blocking
    trackPlantView(plant.value.id);
  }
});

const colorMode = useColorMode();
</script>

<template>
  <div class="mx-auto md:px-8 lg:px-12 xl:max-w-7xl">
    <!-- Loading state -->
    <!-- <div v-if="status === 'pending'"></div> -->
    <div v-if="status === 'pending'" class="pt-4 p-6 md:hidden">
      <!-- Skeleton loader -->
      <div class="mb-10">
        <!-- Image skeleton carousel -->
        <div class="w-full mx-auto rounded-md overflow-hidden">
          <div class="flex gap-4 md:grid md:grid-cols-3">
            <div
              v-for="i in width > 768 ? 3 : 1"
              :key="i"
              class="rounded-lg aspect-square bg-bg-elevated animate-pulse w-full"
            ></div>
          </div>
        </div>
      </div>
      <!-- Title skeleton -->
      <div class="">
        <div class="mb-2">
          <div class="h-10 w-2/3 bg-bg-elevated rounded animate-pulse mb-1"></div>
          <div class="h-6 w-1/3 bg-bg-elevated rounded animate-pulse"></div>
        </div>
      </div>
      <!-- Available skeleton -->
      <div class="mt-18">
        <div class="h-10 w-1/3 md:w-1/4 bg-bg-elevated rounded animate-pulse mb-1"></div>
        <div class="h-6 w-2/3 md:w-1/3 bg-bg-elevated rounded animate-pulse mb-1"></div>
        <div class="h-60 w-full bg-bg-elevated rounded animate-pulse"></div>
      </div>
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
      <!-- Priority 1: Lignosdatabasen images -->
      <div v-if="lignosImages && lignosImages.length" class="mb-10 relative">
        <UCarousel
          v-slot="{ item, index }"
          dots
          :arrows="width > 768"
          :items="lignosImages"
          :back="{ icon: 'material-symbols:arrow-back-rounded' }"
          :next="{ icon: 'material-symbols:arrow-forward-rounded' }"
          slides-to-scroll="auto"
          class="w-full mx-auto rounded-md"
          :ui="{
            item: 'md:basis-1/3',
            dots: 'absolute opacity-70 dark:opacity-100 -translate-y-2',
            dot: 'dark:bg-bg-accented',
          }"
        >
          <img
            :src="item"
            :alt="`${plant?.name || 'Växt'} - Bild ${index + 1}`"
            class="rounded-lg aspect-square object-cover h-full w-full cursor-pointer hover:opacity-90 transition-opacity"
            @click="openLignosImage(item as string, index)"
          />
        </UCarousel>
        <ULink
          :href="`https://lignosdatabasen.se/planta/${lignosdatabasenPlant.slakte}/${
            lignosdatabasenPlant.art
          }${
            lignosdatabasenPlant.sortnamn
              ? `/${lignosdatabasenPlant.sortnamn.replace(`'`, '')}`
              : ''
          }`"
          target="_blank"
          class="absolute max-md:hidden -bottom-7 -right-1 px-2 py-1"
        >
          <!-- Show correct logo depending on theme (dark/light) -->
          <img
            :src="
              colorMode.preference === 'dark'
                ? 'https://res.cloudinary.com/dxwhmugdr/image/upload/v1753737919/logga-text-mörk_ehrwq8.svg'
                : 'https://res.cloudinary.com/dxwhmugdr/image/upload/v1753737919/logga-text-ljus_jeorjy.svg'
            "
            alt="Lignosdatabasen logotyp"
            class="h-4"
            loading="lazy"
          />
        </ULink>
      </div>
      <!-- Priority 2: Database images (Google Photos from database) -->
      <div
        v-else-if="finalImages && Array.isArray(finalImages) && finalImages.length"
        class="mb-10 relative"
      >
        <UCarousel
          v-slot="{ item, index }"
          dots
          :arrows="width > 768"
          :items="finalImages.map((img) => img.url)"
          :back="{ icon: 'material-symbols:arrow-back-rounded' }"
          :next="{ icon: 'material-symbols:arrow-forward-rounded' }"
          slides-to-scroll="auto"
          class="w-full mx-auto rounded-md"
          :ui="{
            item: 'md:basis-1/3',
            dots: 'absolute opacity-70 dark:opacity-100 -translate-y-2',
            dot: 'dark:bg-bg-accented',
          }"
        >
          <img
            :src="item as string"
            :alt="
              Array.isArray(finalImages) && finalImages[index]
                ? finalImages[index].title
                : `${plant?.name || 'Växt'} - Bild ${index + 1}`
            "
            class="rounded-lg aspect-square object-cover h-full w-full cursor-pointer hover:opacity-90 transition-opacity"
            loading="lazy"
            @click="openDatabaseImage(item as string, index)"
          />
        </UCarousel>
        <UIcon
          name="logos:google"
          class="absolute bottom-2 max-md:opacity-80 max-md:saturate-50 md:-bottom-6 right-2"
        />
      </div>
      <!-- Priority 3: Loading state for Google Images -->
      <div
        v-else-if="googleImagesPending"
        class="mb-10 flex items-center justify-center p-8 bg-muted rounded-lg"
      >
        <div class="flex items-center gap-3">
          <UIcon name="i-heroicons-arrow-path" class="w-5 h-5 animate-spin" />
          <span class="text-t-toned">Laddar bilder från Google...</span>
        </div>
      </div>
      <!-- Priority 4: Google Images fallback (freshly fetched) -->
      <div
        v-else-if="googleImages && Array.isArray(googleImages) && googleImages.length"
        class="mb-10 relative"
      >
        <UCarousel
          v-slot="{ item, index }"
          dots
          :arrows="width > 768"
          :items="googleImages.map((img: any) => img.url)"
          :back="{ icon: 'material-symbols:arrow-back-rounded' }"
          :next="{ icon: 'material-symbols:arrow-forward-rounded' }"
          slides-to-scroll="auto"
          class="w-full mx-auto rounded-md"
          :ui="{
            item: 'md:basis-1/3',
            dots: 'absolute opacity-70 dark:opacity-100 -translate-y-2',
            dot: 'dark:bg-bg-accented',
          }"
        >
          <img
            :src="item as string"
            :alt="
              Array.isArray(googleImages) && googleImages[index]
                ? googleImages[index].title
                : `${plant?.name || 'Växt'} - Bild ${index + 1}`
            "
            class="rounded-lg aspect-square object-cover h-full w-full cursor-pointer hover:opacity-90 transition-opacity"
            :loading="shouldPreloadGoogleImage(index) ? 'eager' : 'lazy'"
            @click="openGoogleImage(item as string, index)"
          />
        </UCarousel>
        <!-- Preload next images for smooth carousel navigation -->
        <template v-if="googleImages && Array.isArray(googleImages)">
          <link
            v-for="(img, idx) in getGoogleImagesToPreload()"
            :key="`preload-${idx}`"
            rel="preload"
            as="image"
            :href="img.url"
          />
        </template>
        <UIcon
          name="logos:google"
          class="absolute bottom-2 max-md:opacity-80 max-md:saturate-50 md:-bottom-6 right-2"
        />
      </div>
      <!-- Image Viewer Component -->
      <ImageViewer
        :images="currentImages"
        :initial-index="currentImageIndex"
        :is-open="isImageViewerOpen"
        @close="closeImageViewer"
        @update:current-index="updateImageIndex"
      />
      <div>
        <div class="xl:grid xl:grid-cols-2 xl:gap-16 xl:pt-4">
          <div>
            <div>
              <h1 class="text-3xl font-bold mb-1">{{ plant.name }}</h1>
              <p class="italic text-lg" v-if="plant.sv_name">{{ plant.sv_name }}</p>
              <div
                class="flex justify-between max-[450px]:text-sm max-[360px]:text-xs w-full text-center mt-2 mb-4 border border-border rounded-md py-1"
                v-if="plant.height || plant.spread || fullHeightTimeLabels"
              >
                <!-- <div v-if="rhsTypeLabels" class="flex flex-col items-start grow">
                      <span class="font-bold border-b border-border pb-1 mb-1 w-full min-w-max px-2"
                        >Typ</span
                      >
                      <span class="w-full px-2">{{ rhsTypeLabels }}</span>
                    </div> -->
                <div v-if="plant.height" class="flex flex-col items-center grow">
                  <span class="font-bold border-b border-border pb-1 mb-1 w-full min-w-max px-2"
                    >Höjd</span
                  >
                  <span class="w-full px-2">{{ plant.height }}</span>
                </div>
                <div v-if="plant.spread" class="flex flex-col items-center grow">
                  <span class="font-bold border-b border-border pb-1 mb-1 w-full min-w-max px-2"
                    >Bredd</span
                  >
                  <span class="w-full px-2">{{ plant.spread }}</span>
                </div>
                <div v-if="fullHeightTimeLabels" class="flex flex-col items-end grow">
                  <span class="font-bold border-b border-border pb-1 mb-1 w-full min-w-max px-2"
                    >Tid till fullväxt</span
                  >
                  <span class="w-full px-2">{{ fullHeightTimeLabels }}</span>
                </div>
              </div>
            </div>
            <div v-if="lignosdatabasenPlant" class="mt-4">
              <!-- <div class="prose max-w-none" v-html="lignosText()"></div> -->
              <div class="prose max-w-none" v-html="lignosdatabasenPlant.ingress"></div>
              <div class="mt-2">
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
                  class="p-0 opacity-80"
                >
                  <span v-if="lignosdatabasenPlant.ingress">Läs mer på Lignosdatabasen</span>
                  <span v-else>Läs mer om växten på Lignosdatabasen</span>
                </UButton>
              </div>
            </div>
          </div>
          <!-- Available to Buy Section -->
          <div class="max-xl:mt-12">
            <!-- <h3 class="text-xl lg:text-2xl font-bold">Finns att köpa</h3> -->
            <!-- Loading state for nursery stock -->
            <div v-if="statusStock === 'pending'" class="flex items-center gap-2">
              <UIcon name="i-heroicons-arrow-path" class="animate-spin" />
              <span>Laddar tillgänglighet...</span>
            </div>
            <!-- Error state for nursery stock -->
            <div v-else-if="errorStock" class="text-error">
              <p>Kunde inte ladda tillgänglighetsdata</p>
            </div>
            <!-- No stock available -->
            <div v-else-if="!stockData || stockData.length === 0" class="text-t-toned">
              <div class="flex flex-col items-center gap-4 p-6 bg-muted rounded-lg text-center">
                <UIcon name="i-heroicons-exclamation-triangle" class="w-12 h-12 text-warning" />
                <div>
                  <h4 class="font-semibold text-lg mb-2">Inte tillgänglig just nu</h4>
                  <p class="text-sm">
                    Denna växt finns för närvarande inte tillgänglig hos någon av våra registrerade
                    plantskolor.
                  </p>
                  <p class="text-xs mt-2">
                    Kontakta din lokala plantskola för att höra om de kan beställa hem växten åt
                    dig.
                  </p>
                </div>
                <UButton
                  to="/vaxt/s/"
                  icon="i-heroicons-magnifying-glass"
                  variant="outline"
                  color="primary"
                  size="sm"
                >
                  Sök efter andra växter
                </UButton>
              </div>
            </div>
            <!-- Stock data available -->
            <div v-else class="space-y-3">
              <!-- <p class="text-sm text-t-toned">
                {{ stockData.length }} plantskol{{ stockData.length === 1 ? 'a' : 'or' }}
                har denna växt i lager
              </p> -->
              <div class="grid gap-4">
                <!-- Grouped by nursery -->
                <article
                  v-for="group in groupedStockData"
                  :key="group.nursery.nursery_name + (group.nursery.nursery_address || '')"
                  class=""
                  itemscope
                  itemtype="https://schema.org/Offer"
                >
                  <!-- Nursery Header -->
                  <header class="flex flex-col sm:flex-row sm:items-start gap-2 mb-3">
                    <div class="flex-1">
                      <ULink
                        :to="`/plantskola/${group.nursery.plantskola_id}`"
                        class="text-xl text-t-regular font-bold hover:opacity-80"
                        itemprop="seller"
                        itemscope
                        itemtype="https://schema.org/Organization"
                      >
                        <span itemprop="name">{{ group.nursery.nursery_name }}</span>
                      </ULink>
                      <p
                        v-if="group.nursery.nursery_address && group.nursery.nursery_on_site"
                        class="text-sm text-t-toned flex items-center"
                        itemprop="address"
                      >
                        <UIcon name="i-heroicons-map-pin" class="inline-block mr-1" />
                        <span class="mr-1 font-bold">Hämtning på plats:</span>
                        <span itemprop="streetAddress">{{ group.nursery.nursery_address }}</span>
                      </p>
                      <p v-else-if="group.nursery.nursery_on_site" class="text-sm text-t-toned">
                        Hämtning på plats
                      </p>
                      <UBadge
                        variant="soft"
                        color="neutral"
                        size="sm"
                        icon="material-symbols:delivery-truck-speed-outline-rounded"
                        v-if="group.nursery.nursery_postorder"
                        >Postorder</UBadge
                      >
                    </div>
                  </header>
                  <!-- Multiple plant details for this nursery -->
                  <div class="flex flex-col gap-4 border-t border-border pt-2">
                    <div
                      v-for="stock in group.plants"
                      :key="stock.id"
                      class="mb-2 pb-2 border-b border-border last:border-b-0 last:mb-0 last:pb-0"
                    >
                      <!-- Stock and Price -->
                      <div class="flex items-center gap-4 flex-wrap">
                        <div class="flex items-center gap-2" v-if="stock.stock > 0">
                          <span
                            class="font-medium"
                            itemprop="availability"
                            content="https://schema.org/InStock"
                          >
                            <span class="font-bold">{{ stock.stock }}</span> st i lager
                          </span>
                        </div>
                        <div v-if="stock.price" class="flex items-center gap-2">
                          <span class="font-medium">
                            <span itemprop="price" :content="stock.price" class="font-bold">{{
                              stock.price
                            }}</span>
                            <span itemprop="priceCurrency" content="SEK"> kr</span>
                          </span>
                        </div>
                      </div>
                      <!-- Plant specifications -->
                      <div
                        class="flex items-center gap-4 flex-wrap text-sm"
                        v-if="stock.pot || stock.height"
                      >
                        <div v-if="stock.pot" class="flex items-center gap-1">
                          Krukstorlek:
                          <span class="font-semibold">{{ stock.pot }}</span>
                        </div>
                        <div v-if="stock.height" class="flex items-center gap-1">
                          Höjd:
                          <span class="font-semibold">{{ stock.height }}</span>
                          cm
                        </div>
                      </div>
                      <!-- Nursery's plant name (if different) -->
                      <!-- <div
                            v-if="stock.name_by_plantskola && stock.name_by_plantskola !== plant?.name"
                            class="text-sm"
                          >
                            <span class="font-medium">Plantskolans namn:</span>
                            <span class="italic ml-1">{{ stock.name_by_plantskola }}</span>
                          </div> -->
                      <!-- Nursery's comment -->
                      <div v-if="stock.comment_by_plantskola" class="text-sm">
                        <span class="font-medium">Kommentar:</span>
                        <span class="ml-1">{{ stock.comment_by_plantskola }}</span>
                      </div>
                    </div>
                  </div>
                  <!-- Contact Information -->
                  <footer
                    class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2 mt-4 pt-3 border-t border-border"
                  >
                    <div class="flex items-center gap-3 flex-wrap">
                      <!-- Email dropdown -->
                      <UDropdownMenu
                        v-if="group.nursery.nursery_email"
                        :items="[
                          [
                            {
                              label: 'Kopiera e-post',
                              icon: 'i-heroicons-clipboard-document',
                              onSelect: () => copyToClipboard(group.nursery.nursery_email || ''),
                            },
                          ],
                          [
                            {
                              label: 'Skicka e-post',
                              icon: 'i-heroicons-envelope',
                              onSelect: () =>
                                navigateTo(`mailto:${group.nursery.nursery_email}`, {
                                  external: true,
                                }),
                            },
                          ],
                        ]"
                      >
                        <UButton
                          icon="i-heroicons-envelope"
                          color="primary"
                          variant="outline"
                          size="sm"
                          trailing-icon="i-heroicons-chevron-down-20-solid"
                        >
                          E-post
                        </UButton>
                      </UDropdownMenu>
                      <!-- Phone dropdown -->
                      <UDropdownMenu
                        v-if="group.nursery.nursery_phone"
                        :items="[
                          [
                            {
                              label: 'Kopiera telefonnummer',
                              icon: 'i-heroicons-clipboard-document',
                              onSelect: () => copyToClipboard(group.nursery.nursery_phone || ''),
                            },
                          ],
                          [
                            {
                              label: 'Ring upp',
                              icon: 'i-heroicons-phone',
                              onSelect: () =>
                                navigateTo(`tel:${group.nursery.nursery_phone}`, {
                                  external: true,
                                }),
                            },
                          ],
                        ]"
                      >
                        <UButton
                          icon="i-heroicons-phone"
                          color="primary"
                          variant="outline"
                          size="sm"
                          trailing-icon="i-heroicons-chevron-down-20-solid"
                        >
                          {{ group.nursery.nursery_phone }}
                        </UButton>
                      </UDropdownMenu>
                      <UButton
                        v-if="group.nursery.nursery_url"
                        :href="group.nursery.nursery_url"
                        target="_blank"
                        rel="noopener noreferrer"
                        icon="i-heroicons-globe-alt"
                        color="primary"
                        variant="outline"
                        size="sm"
                      >
                        Besök webbsida
                      </UButton>
                    </div>
                    <!-- Last updated info: show the latest last_edited among all plants for this nursery -->
                    <div class="text-xs text-t-muted self-start sm:self-center">
                      Uppdaterat
                      {{
                        formatDate(
                          group.plants.reduce(
                            (latest, s) => (s.last_edited > latest ? s.last_edited : latest),
                            group.plants[0]?.last_edited || ''
                          )
                        )
                      }}
                    </div>
                  </footer>
                </article>
              </div>
            </div>
          </div>
        </div>
        <!-- Growing Conditions -->
        <div
          class="mt-12 lg:mt-16"
          v-if="sunlightLabels || exposureLabels || soilTypeLabels || phLabels || moistureLabels"
        >
          <h3 class="text-xl lg:text-2xl font-bold">Odlingsförhållanden</h3>
          <div
            class="flex flex-wrap w-full justify-between border border-border rounded-md py-1 text-center mt-2"
          >
            <div v-if="sunlightLabels" class="flex flex-col grow">
              <span class="font-bold mb-1 pb-1 border-b border-border">Ljus</span>
              <div class="flex gap-2 items-center justify-center">
                <template v-for="(label, idx) in sunlightLabels.split(' / ')" :key="idx">
                  <UIcon
                    :name="
                      label.trim() === 'Soligt'
                        ? 'material-symbols:sunny-outline-rounded'
                        : label.trim() === 'Delvis skuggigt'
                        ? 'fluent:weather-partly-cloudy-day-16-regular'
                        : label.trim() === 'Helt skuggigt'
                        ? 'ic:outline-wb-cloudy'
                        : 'mdi:help-circle-outline'
                    "
                    class="w-6 h-6"
                    :title="label.trim()"
                  />
                  <span
                    v-if="idx < sunlightLabels.split(' / ').length - 1"
                    class="text-t-muted text-lg leading-0"
                    >/</span
                  >
                </template>
              </div>
            </div>
            <div v-if="exposureLabels" class="flex flex-col grow">
              <span class="font-bold mb-1 pb-1 border-b border-border">Exponering</span>
              <span>{{ exposureLabels }}</span>
            </div>
          </div>
          <!-- Desktop view -->
          <div
            class="flex flex-wrap w-full justify-between border border-border rounded-md py-1 text-center max-md:hidden mt-4"
            v-if="soilTypeLabels || phLabels || moistureLabels"
          >
            <div v-if="soilTypeLabels" class="flex flex-col grow">
              <span class="font-bold mb-1 pb-1 border-b border-border">Jord</span>
              <span>{{ soilTypeLabels }}</span>
            </div>
            <div v-if="phLabels" class="flex flex-col grow">
              <span class="font-bold mb-1 pb-1 border-b border-border">pH</span>
              <span>{{ phLabels }}</span>
            </div>
            <div v-if="moistureLabels" class="flex flex-col grow">
              <span class="font-bold mb-1 pb-1 border-b border-border">Fuktighet</span>
              <span>{{ moistureLabels }}</span>
            </div>
          </div>
          <!-- Mobile view -->
          <div
            class="flex w-full flex-col border border-border rounded-md py-1 text-center md:hidden mt-4"
            v-if="soilTypeLabels || phLabels || moistureLabels"
          >
            <span class="font-bold mb-1 pb-1 border-b border-border">Jord</span>
            <span class="mb-1 pb-1 border-b border-border">{{ soilTypeLabels }}</span>
            <span class="mb-1 pb-1 border-b border-border">{{ phLabels }}</span>
            <span>{{ moistureLabels }}</span>
          </div>
          <!-- Temporarily disabled -->
          <div
            v-if="graphicalPlantBySeason && false"
            class="mt-4 pt-4 pb-1 border border-border rounded-md"
          >
            <!-- Graphical timeline -->
            <div class="relative pt-4">
              <!-- Timeline line -->
              <div class="absolute bottom-6 left-0 right-0 h-0.25 bg-border"></div>
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

<style>
.rounded-full.transition.bg-\(--ui-border-inverted\) {
  opacity: 0.8;
}
.rounded-full.transition.bg-\(--ui-border-inverted\) {
  &:where(.dark, .dark *) {
    opacity: 0.9;
    background: var(--ui-text-muted);
  }
}
/* Add any custom styles if needed */
</style>
