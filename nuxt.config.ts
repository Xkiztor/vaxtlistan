// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  compatibilityDate: '2024-11-01',
  devtools: { enabled: true },
  modules: [
    '@nuxt/ui',
    '@nuxt/image',
    '@pinia/nuxt',
    '@nuxtjs/supabase',
    '@vueuse/nuxt',
  ],
  css: ['~/assets/css/main.css'],
  supabase: {
    // redirect: false
    redirectOptions: {
      login: '/admin/login',
      callback: '/admin',
      include: ['/admin(/*)?'],
    }
  },
  runtimeConfig: {
    public: {
      LINDERSPLANTSKOLA_SUPABASE_URL: process.env.LINDERSPLANTSKOLA_SUPABASE_URL,
      LINDERSPLANTSKOLA_SUPABASE_KEY: process.env.LINDERSPLANTSKOLA_SUPABASE_KEY,
    },
  },
  ui: {
    theme: {
      colors: [
        'primary',
        'secondary',
        'info',
        'success',
        'warning',
        'error',
        'trad',
        'barrtrad',
        'perenn',
        'ormbunke',
        'gras',
        'klattervaxt',
      ]
    }
  }
  
})