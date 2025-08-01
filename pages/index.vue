<script setup lang="ts">
import type { RandomPlantWithStock } from '~/composables/useRandomPlants';

// SEO metadata for the homepage
useHead({
  title: 'Växtlistan - Hitta växter från Sveriges plantskolor',
  meta: [
    {
      name: 'description',
      content:
        'Sök, jämför och hitta växter från Sveriges plantskolor. Som Prisjakt fast för växter - se direkt var din favoritväxt säljs utan att klicka runt på massa olika hemsidor.',
    },
    {
      name: 'keywords',
      content:
        'växter, hitta, plantskolor, växtsök, växthandel, trädgård, plantor, sverige, växtlistan',
    },
    {
      property: 'og:title',
      content: 'Växtlistan - Hitta växter från Sveriges plantskolor',
    },
    {
      property: 'og:description',
      content:
        'Sök, jämför och hitta växter från Sveriges plantskolor. Som Prisjakt fast för växter.',
    },
    {
      property: 'og:type',
      content: 'website',
    },
    {
      property: 'og:url',
      content: 'https://vaxtlistan.se',
    },
    {
      name: 'twitter:card',
      content: 'summary_large_image',
    },
    {
      name: 'twitter:title',
      content: 'Växtlistan - Hitta växter från Sveriges plantskolor',
    },
    {
      name: 'twitter:description',
      content:
        'Sök, jämför och hitta växter från Sveriges plantskolor. Som Prisjakt fast för växter.',
    },
  ],
  link: [
    {
      rel: 'canonical',
      href: 'https://vaxtlistan.se',
    },
  ],
});

// Fetch random plants for the homepage
const { fetchRandomPlants } = useRandomPlants(6);

const {
  data: randomPlants,
  status: plantsStatus,
  error: plantsError,
} = await useAsyncData<RandomPlantWithStock[]>(
  'homepage-random-plants',
  () => fetchRandomPlants(),
  {
    lazy: true,
    default: () => [], // Default empty array
  }
);

// Scroll detection for gradient overlays
const scrollContainer = ref<HTMLElement>();
const showLeftGradient = ref(false);
const showRightGradient = ref(false);

// Check scroll position to show/hide gradients
const checkScrollPosition = () => {
  if (!scrollContainer.value) return;

  const { scrollLeft, scrollWidth, clientWidth } = scrollContainer.value;

  // Show left gradient if scrolled right from start
  showLeftGradient.value = scrollLeft > 0;

  // Show right gradient if there's more content to scroll
  showRightGradient.value = scrollLeft < scrollWidth - clientWidth - 1;
};

// Initialize scroll position check when component mounts
onMounted(() => {
  if (scrollContainer.value) {
    checkScrollPosition();
  }
});
</script>

<template>
  <div class="">
    <main>
      <header class="md:p-4 relative md:min-h-[100vh] grid">
        <!-- Background image showing the bottom of the plant image -->
        <!-- <img
          class="absolute inset-0 w-full h-full object-cover object-bottom"
          src="https://images.unsplash.com/photo-1696914083279-3ce7756f41a4?q=80&w=2070&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D"
          alt="Acer palmatum 'Osakazuki' - Foto Peter Linder"
        /> -->
        <!-- <img
          class="absolute inset-4 w-full max-w-[calc(100vw-2rem)] h-full max-h-[calc(100vh-5rem-2rem)] object-cover rounded-4xl bg-[#76994e]"
          src="https://static.tildacdn.com/tild6331-3063-4631-a139-323064326435/Frame_967.svg"
          alt="Acer palmatum 'Osakazuki' - Foto Peter Linder"
        /> -->
        <!-- <img
          class="absolute inset-4 w-full max-w-[calc(100vw-2rem)] h-full max-h-[calc(100vh-5rem-2rem)] object-cover object-top rounded-4xl"
          src="https://res.cloudinary.com/dxwhmugdr/image/upload/v1753535141/IMG_5430_maalwc.jpg"
          alt="Acer palmatum 'Osakazuki' - Foto Peter Linder"
        /> -->
        <!-- <img
          class="absolute inset-0 w-full h-full object-cover object-bottom"
          src="https://res.cloudinary.com/dxwhmugdr/image/upload/v1752052968/Acer-palmatum-_Osakazuki_-Foto-Peter-Linder-Li_70033_ykobbx.jpg"
          alt="Acer palmatum 'Osakazuki' - Foto Peter Linder"
        /> -->
        <!-- Dark gradient overlay at bottom for better text readability -->
        <!-- <div
          class="absolute inset-0 top-1/2 bg-gradient-to-t from-black/40 via-black/20 to-transparent"
        ></div> -->
        <div
          class="w-full h-full md:rounded-3xl hero-bg flex flex-col items-center justify-center text-center pt-18 pb-12 lg:py-8"
        >
          <h1 class="font-black text-white title border-b-2 border-white mb-4 pb-2 lg:px-16">
            Växtlistan
          </h1>
          <h2 class="lg:max-w-[60vw] text-white font-semibold slogan px-4">
            Vi sammanställer utbudet från Sveriges plantskolor så du snabbt och enkelt kan hitta det
            du söker.
            <!-- Hitta växter snabbt och enkelt från Sveriges största utbud. -->
          </h2>
          <UButton
            size="xl"
            variant="outline"
            color="neutral"
            class="mt-6 md:py-3 md:px-8 tracking-wide bg-transparent text-white ring-white ring-2 hover:bg-white/20 md:text-lg font-bold"
            to="/vaxt/s"
            >Se alla växter</UButton
          >
          <section class="p-6 mt-8 lg:pt-16 flex items-center justify-center gap-4 text-white">
            <UIcon name="bx:bxs-quote-alt-left" class="text-5xl md:text-7xl text-white mb-12" />
            <h2
              class="font-semibold text-center slogan tracking-wider md:border-b-2 md:border-white/70"
            >
              <span class="block md:inline">Som Prisjakt fast</span><span> för växter</span>
            </h2>
            <UIcon name="bx:bxs-quote-alt-right" class="text-5xl md:text-7xl text-white mt-12" />
          </section>
        </div>
      </header>
      <!-- <section class="p-4 py-4 lg:py-12 flex items-center justify-center gap-0 md:gap-4">
        <UIcon name="bx:bxs-quote-alt-left" class="text-5xl md:text-7xl text-bg-elevated mb-12" />
        <h2
          class="font-semibold text-center slogan tracking-wider md:border-b-2 md:border-primary/80"
        >
          Som Prisjakt fast för växter
        </h2>
        <UIcon name="bx:bxs-quote-alt-right" class="text-5xl md:text-7xl text-bg-elevated mt-12" />
      </section> -->
      <section class="mt-12 w-full grid">
        <div
          class="w-full rounded-3xl flex flex-col items-center justify-center px-6 md:px-24 gap-6"
        >
          <p class="text-xl md:text-2xl font-semibold text-center max-w-[50ch]">
            Växtlistan erbjuder Sveriges största utbud av växter
          </p>
          <p class="text-xl md:text-2xl font-semibold text-center max-w-[50ch]">
            Sök, jämför och se direkt vart växterna säljs - utan att leta runt bland massa olika
            hemsidor.
          </p>
          <UButton
            to="/om-oss"
            size="xl"
            variant="outline"
            color="neutral"
            class="py-3 px-8 tracking-wide font-bold"
          >
            Läs mer om oss <UIcon name="ph:arrow-right" class="ml-2" />
          </UButton>
        </div>
      </section>
      <section class="p-4 py-12 mt-6">
        <div class="max-w-7xl mx-auto">
          <div class="text-center mb-6 md:mb-8">
            <h2 class="text-2xl md:text-3xl font-bold">Är du kanske intresserad av</h2>
          </div>

          <!-- Loading state -->
          <div
            v-if="plantsStatus === 'pending'"
            class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6"
          >
            <div
              v-for="i in 6"
              :key="i"
              class="bg-gray-100 dark:bg-gray-800 rounded-2xl animate-pulse"
            >
              <div class="aspect-square bg-bg-elevated rounded-t-2xl"></div>
              <div class="p-4 space-y-3">
                <div class="h-4 bg-bg-elevated rounded w-3/4"></div>
                <div class="h-3 bg-bg-elevated rounded w-1/2"></div>
                <div class="h-6 bg-bg-elevated rounded w-1/3"></div>
              </div>
            </div>
          </div>

          <!-- Random plants grid -->
          <div v-else-if="randomPlants && randomPlants.length > 0" class="relative">
            <!-- Horizontal scroll container for smaller screens -->
            <div class="xl:hidden relative">
              <!-- Left gradient overlay -->
              <Transition name="fade">
                <div
                  v-if="showLeftGradient"
                  class="absolute left-0 top-0 z-10 w-4 h-full bg-gradient-to-r from-bg to-transparent pointer-events-none"
                ></div>
              </Transition>

              <!-- Right gradient overlay -->
              <Transition name="fade">
                <div
                  v-if="showRightGradient"
                  class="absolute right-0 top-0 z-10 w-8 h-full bg-gradient-to-l from-bg to-transparent pointer-events-none"
                ></div>
              </Transition>

              <!-- Scrollable container -->
              <div ref="scrollContainer" class="overflow-x-auto pb-2" @scroll="checkScrollPosition">
                <div class="grid-cols-6 flex gap-4 w-fit">
                  <div v-for="plant in randomPlants" :key="plant.id" class="w-36 sm:w-48">
                    <RandomPlantCard :plant="plant" />
                  </div>
                </div>
              </div>
            </div>

            <!-- Grid layout for xl and larger screens -->
            <div class="hidden xl:grid xl:grid-cols-6 xl:gap-6">
              <RandomPlantCard v-for="plant in randomPlants" :key="plant.id" :plant="plant" />
            </div>
          </div>

          <!-- Error or empty state -->
          <div v-else class="text-center py-12">
            <UIcon name="ph:plant" class="text-6xl text-gray-400 mb-4" />
            <h3 class="text-xl font-semibold text-gray-900 dark:text-gray-100 mb-2">
              Inga växter kunde laddas just nu
            </h3>
            <p class="text-gray-600 dark:text-gray-400">
              Försök ladda om sidan eller kom tillbaka senare
            </p>
          </div>

          <!-- Call to action -->
          <div class="text-center mt-6">
            <UButton
              to="/vaxt/s"
              size="xl"
              color="primary"
              variant="outline"
              class="px-8 py-3 font-semibold"
            >
              Se alla växter
              <UIcon name="ph:arrow-right" class="ml-2" />
            </UButton>
          </div>
        </div>
      </section>
      <section class="p-4 py-12">
        <div class="max-w-4xl mx-auto text-center">
          <h2 class="text-2xl md:text-3xl font-bold mb-4">Har du plantskola?</h2>
          <p class="text-t-toned mb-8 max-w-2xl mx-auto">
            Registrera dig på Växtlistan och nå ut till fler kunder. Visa ditt sortiment och öka din
            försäljning.
          </p>
          <UButton
            size="xl"
            variant="outline"
            color="neutral"
            class="py-3 px-8 tracking-wide font-bold"
            to="/for-plantskolor"
          >
            Information för plantskolor
            <UIcon name="ph:arrow-right" class="ml-2" />
          </UButton>
        </div>
      </section>
    </main>
  </div>
</template>

<style>
.hero-bg {
  /* background: linear-gradient(45deg, var(--primary-green-dark), var(--primary-green-light)); */
  /* background: radial-gradient(var(--primary-green-dark), red); */
  background: radial-gradient(ellipse at top left, #619c66, transparent),
    radial-gradient(ellipse at top right, rgb(198, 200, 93), transparent),
    radial-gradient(ellipse at bottom, #76994e, transparent);
}

.title {
  /* text-shadow: 0 2px 30px rgba(0, 0, 0, 0.5); */
  font-size: clamp(3rem, 10vw, 8rem);
  letter-spacing: 0.02em;
  line-height: 1;
}

.slogan {
  font-size: clamp(1rem, 5vw, 2rem);
  /* letter-spacing: 0.005em; */
}

/* Hide scrollbar while keeping functionality */
.scrollbar-hide {
  -ms-overflow-style: none; /* Internet Explorer 10+ */
  scrollbar-width: none; /* Firefox */
}

.scrollbar-hide::-webkit-scrollbar {
  display: none; /* Safari and Chrome */
}

@media screen and (max-width: 768px) {
  .slogan {
    font-size: clamp(0.8rem, 4.5vw, 2rem);
    /* letter-spacing: 0.005em; */
  }
}

/* Smooth fade transition for gradient overlays */
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.15s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
</style>
