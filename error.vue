<template>
  <div class="min-h-screen">
    <NuxtLayout name="default" class="h-full">
      <div class="flex flex-col items-center justify-center h-full px-4 py-16">
        <div class="flex items-center justify-center mb-8 space-x-2 md:space-x-4">
          <!-- Show 404 with plant backgrounds only for 404 errors -->
          <h1
            v-if="error?.statusCode === 404"
            class="text-[42vw] md:text-[30vw] font-black leading-[0.8]"
          >
            <span class="digit-4-first">4</span>
            <span class="digit-0">0</span>
            <span class="digit-4-second">4</span>
          </h1>
          <!-- Show error status code for other errors -->
          <h1 v-else class="text-[42vw] md:text-[30vw] font-black leading-[0.8]">
            {{ error?.statusCode || 'Error' }}
          </h1>
        </div>
        <!-- Error message -->
        <div class="text-center max-w-2xl mx-auto">
          <h2 class="text-2xl md:text-4xl font-bold mb-4" v-if="error?.statusCode === 404">
            Sidan kunde inte hittas
          </h2>
          <h2 class="text-2xl md:text-4xl font-bold mb-4" v-else>Ett fel uppstod</h2>
          <div
            v-if="error?.statusCode !== 404"
            class="text-sm border border-error rounded-lg p-4 mb-6"
          >
            <p>{{ error?.statusMessage }}</p>
            <p>{{ error?.cause }}</p>
            <p>{{ error?.message }}</p>
          </div>
          <p class="text-lg md:text-xl text-t-toned mb-8">
            {{
              error?.statusCode === 404
                ? 'Den sida du letar efter verkar inte existera längre.'
                : 'Något gick fel. Försök igen eller kontakta support om problemet kvarstår.'
            }}
          </p>

          <!-- Action buttons -->
          <div class="flex flex-col sm:flex-row gap-4 justify-center">
            <UButton to="/" size="lg" color="primary" variant="solid" class="">
              <UIcon name="i-heroicons-home" class="mr-2" />
              Gå till startsidan
            </UButton>
            <UButton @click="$router.go(-1)" size="lg" color="neutral" variant="outline" class="">
              <UIcon name="i-heroicons-arrow-left" class="mr-2" />
              Gå tillbaka
            </UButton>
          </div>
        </div>
      </div>
    </NuxtLayout>
  </div>
</template>

<script setup lang="ts">
// Define page metadata for SEO
definePageMeta({
  title: '404 - Sida hittades inte',
  description: 'Den begärda sidan kunde inte hittas.',
  layout: 'default',
});

// Get error from Nuxt
const error = useError();

// Set proper status code for SEO
useHead({
  title: `${error.value?.statusCode || 404} - Sida hittades inte`,
  meta: [
    {
      name: 'robots',
      content: 'noindex, nofollow',
    },
  ],
});
</script>

<style scoped>
/* Ensure proper image background clipping */
.digit-4-first,
.digit-0,
.digit-4-second {
  -webkit-background-clip: text !important;
  background-clip: text !important;
  -webkit-text-fill-color: transparent;
}

/* Background images for each digit */
.digit-4-first {
  background-image: url('https://res.cloudinary.com/dxwhmugdr/image/upload/h_900/f_auto/q_auto/v1752052968/Acer-palmatum-_Osakazuki_-Foto-Peter-Linder-Li_70033_ykobbx.jpg');
  background-size: cover;
  background-position: center top;
}

.digit-0 {
  background-image: url('https://res.cloudinary.com/dxwhmugdr/image/upload/w_600/f_auto/q_auto/v1752052454/IMG_4193_yd4ikb.jpg');
  background-size: cover;
  background-position: center center;
}

.digit-4-second {
  background-image: url('https://res.cloudinary.com/dxwhmugdr/image/upload/w_600/f_auto/q_auto/v1752051120/IMG_4267_msutdv.jpg');
  background-size: cover;
  background-position: center bottom;
}
/* Background images for each digit */
.dark .digit-4-first {
  background-image: url('https://res.cloudinary.com/dxwhmugdr/image/upload/w_600/f_auto/q_auto/v1751802072/IMG_4182_lh1bau.jpg');
  background-size: cover;
  background-position: center top;
}

.dark .digit-0 {
  background-image: url('https://res.cloudinary.com/dxwhmugdr/image/upload/w_600/f_auto/q_auto/v1752051026/IMG_4436_qi9td6.jpg');
  background-size: cover;
  background-position: center center;
}

.dark .digit-4-second {
  background-image: url('https://res.cloudinary.com/dxwhmugdr/image/upload/w_600/f_auto/q_auto/v1752053163/Ginkgo_biloba_Li_73379_mojcxj.jpg');
  background-size: cover;
  background-position: center bottom;
}

/* Fallback for browsers that don't support background-clip: text */
@supports not (background-clip: text) {
  .digit-4-first,
  .digit-0,
  .digit-4-second {
    background: var(--ui-primary);
    -webkit-background-clip: text;
    background-clip: text;
  }
}
</style>
