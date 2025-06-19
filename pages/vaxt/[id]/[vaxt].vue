<script setup lang="ts">
// Import Nuxt composables and Supabase client
import type { Facit } from '~/types/supabase-tables';
import { useLignosdatabasen } from '~/stores/lignosdatabasen';
import { computed } from 'vue';

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

// Fetch stock data for this plant from nurseries
const {
  data: stockData,
  status: statusStock,
  error: errorStock,
  pending: pendingStock,
} = await useAsyncData<PlantStock[]>(
  `plant-stock-${id.value}`,
  async () => {
    if (!plant.value?.id) return [];
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
      .eq('facit_id', plant.value.id)
      .eq('hidden', false)
      .eq('plantskolor.verified', true)
      .gt('stock', 0)
      .order('stock', { ascending: false });
    if (error) {
      console.error('Error fetching stock data:', error.message);
      throw error;
    }

    // Transform the data to include nursery information at the top level
    return (data || []).map((item: any) => ({
      id: item.id,
      stock: item.stock,
      price: item.price,
      pot: item.pot,
      height: item.height,
      name_by_plantskola: item.name_by_plantskola,
      comment_by_plantskola: item.comment_by_plantskola,
      last_edited: item.last_edited,
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
    watch: [() => plant.value?.id],
    default: () => [],
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
  desc = desc.replace(/text=".*?"/g, ''); // Remove any text="..." attributes
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
      <div v-if="lignosImages" class="mb-10">
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
        <div class="flex flex-wrap items-center gap-4 mt-4">
          <div v-if="rhsTypeLabels" class="flex flex-wrap items-center gap-2">
            <span class="font-semibold">Typ:</span>
            <UBadge
              v-for="label in rhsTypeLabels.split(' / ')"
              :key="label"
              color="primary"
              size="lg"
              variant="soft"
            >
              {{ label.trim() }}
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

        <div v-if="lignosdatabasenPlant" class="mb-4">
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
        <!-- Available to Buy Section -->
        <div class="space-y-4 mb-4">
          <h3 class="text-xl font-semibold">Finns att köpa</h3>

          <!-- Loading state for nursery stock -->
          <div v-if="pendingStock" class="flex items-center gap-2">
            <UIcon name="i-heroicons-arrow-path" class="animate-spin" />
            <span>Laddar tillgänglighet...</span>
          </div>

          <!-- Error state for nursery stock -->
          <div v-else-if="errorStock" class="text-error">
            <p>Kunde inte ladda tillgänglighetsdata</p>
          </div>
          <!-- No stock available -->
          <div v-else-if="!stockData || stockData.length === 0" class="text-t-muted">
            <div class="flex flex-col items-center gap-4 p-6 bg-muted rounded-lg text-center">
              <UIcon name="i-heroicons-exclamation-triangle" class="w-12 h-12 text-warning" />
              <div>
                <h4 class="font-semibold text-lg mb-2">Inte tillgänglig just nu</h4>
                <p class="text-sm">
                  Denna växt finns för närvarande inte tillgänglig hos någon av våra registrerade
                  plantskolor.
                </p>
                <p class="text-xs mt-2">
                  Kontakta din lokala plantskola för att höra om de kan beställa hem växten åt dig.
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
            <p class="text-sm text-t-muted">
              {{ stockData.length }} plantskol{{ stockData.length === 1 ? 'a' : 'or' }} har denna
              växt i lager
            </p>
            <div class="grid gap-4">
              <article
                v-for="stock in stockData"
                :key="stock.id"
                class="border border-border rounded-lg p-4 hover:shadow-md transition-shadow bg-card"
                itemscope
                itemtype="https://schema.org/Offer"
              >
                <!-- Nursery Header -->
                <header class="flex flex-col sm:flex-row sm:items-start gap-2 mb-3">
                  <div class="flex-1">
                    <h4
                      class="font-semibold text-lg"
                      itemprop="seller"
                      itemscope
                      itemtype="https://schema.org/Organization"
                    >
                      <span itemprop="name">{{ stock.nursery_name }}</span>
                    </h4>
                    <p v-if="stock.nursery_address" class="text-sm text-t-muted" itemprop="address">
                      {{ stock.nursery_address }}
                    </p>
                  </div>
                </header>

                <!-- Plant Details -->
                <div class="space-y-3">
                  <!-- Stock and Price -->
                  <div class="flex items-center gap-4 flex-wrap">
                    <div class="flex items-center gap-2">
                      <UIcon name="i-heroicons-cube" class="text-primary flex-shrink-0" />
                      <span
                        class="font-medium"
                        itemprop="availability"
                        content="https://schema.org/InStock"
                      >
                        {{ stock.stock }} st i lager
                      </span>
                    </div>
                    <div v-if="stock.price" class="flex items-center gap-2">
                      <UIcon
                        name="i-heroicons-currency-dollar"
                        class="text-success flex-shrink-0"
                      />
                      <span class="font-medium">
                        <span itemprop="price" :content="stock.price">{{ stock.price }}</span>
                        <span itemprop="priceCurrency" content="SEK"> kr</span>
                      </span>
                    </div>
                  </div>

                  <!-- Plant specifications -->
                  <div class="flex items-center gap-4 flex-wrap text-sm">
                    <div v-if="stock.pot" class="flex items-center gap-1">
                      <UIcon
                        name="i-heroicons-square-3-stack-3d"
                        class="text-t-muted flex-shrink-0"
                      />
                      <span>{{ stock.pot }}</span>
                    </div>
                    <div v-if="stock.height" class="flex items-center gap-1">
                      <UIcon name="i-heroicons-arrow-up" class="text-t-muted flex-shrink-0" />
                      <span>{{ stock.height }}</span>
                    </div>
                  </div>

                  <!-- Nursery's plant name (if different) -->
                  <div
                    v-if="stock.name_by_plantskola && stock.name_by_plantskola !== plant?.name"
                    class="text-sm"
                  >
                    <span class="font-medium">Plantskolans namn:</span>
                    <span class="italic ml-1">{{ stock.name_by_plantskola }}</span>
                  </div>
                  <!-- Nursery's comment -->
                  <div v-if="stock.comment_by_plantskola" class="text-sm">
                    <span class="font-medium">Kommentar:</span>
                    <span class="ml-1">{{ stock.comment_by_plantskola }}</span>
                  </div>
                  <!-- Postorder information -->
                  <div class="text-sm flex items-center gap-2">
                    <span class="font-medium">Postorder:</span>
                    <UBadge
                      :color="stock.nursery_postorder ? 'success' : 'neutral'"
                      variant="soft"
                      size="sm"
                    >
                      {{
                        stock.nursery_postorder ? 'Ja, skickar via post' : 'Nej, endast hämtning'
                      }}
                    </UBadge>
                  </div>

                  <!-- On-site pickup information -->
                  <div class="text-sm flex items-center gap-2">
                    <span class="font-medium">Hämtning på plats:</span>
                    <UBadge
                      :color="stock.nursery_on_site ? 'success' : 'neutral'"
                      variant="soft"
                      size="sm"
                    >
                      {{ stock.nursery_on_site ? 'Ja, hämtning möjlig' : 'Nej, ingen hämtning' }}
                    </UBadge>
                  </div>
                </div>

                <!-- Contact Information -->
                <footer
                  class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 mt-4 pt-3 border-t border-border"
                >
                  <div class="flex items-center gap-3 flex-wrap">
                    <UButton
                      v-if="stock.nursery_email"
                      :href="`mailto:${stock.nursery_email}?subject=Intresse för ${plant?.name}&body=Hej,%0D%0A%0D%0AJag är intresserad av att köpa ${plant?.name} som ni har i er plantskola.%0D%0A%0D%0AMvh`"
                      icon="i-heroicons-envelope"
                      color="primary"
                      variant="outline"
                      size="sm"
                    >
                      Skicka e-post
                    </UButton>

                    <UButton
                      v-if="stock.nursery_phone"
                      :href="`tel:${stock.nursery_phone}`"
                      icon="i-heroicons-phone"
                      color="primary"
                      variant="outline"
                      size="sm"
                    >
                      Ring
                    </UButton>

                    <UButton
                      v-if="stock.nursery_url"
                      :href="stock.nursery_url"
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

                  <!-- Last updated info -->
                  <div class="text-xs text-t-muted self-start sm:self-center">
                    Uppdaterat {{ formatDate(stock.last_edited) }}
                  </div>
                </footer>
              </article>
            </div>
          </div>
        </div>

        <!-- Growing Conditions -->
        <div
          class="space-y-2 mb-4"
          v-if="sunlightLabels || exposureLabels || soilTypeLabels || phLabels || moistureLabels"
        >
          <h3 class="text-xl font-semibold">Odlingsförhållanden</h3>
          <div class="flex flex-wrap gap-2 w-full justify-between md:gap-16">
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
        <div class="mb-4 space-y-4" v-if="colorsBySeason || seasonOfInterestLabels">
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
