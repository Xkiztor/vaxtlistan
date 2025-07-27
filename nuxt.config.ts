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
    'nuxt-charts',
    '@nuxtjs/sitemap'
  ],
    experimental: {
    payloadExtraction: true,
  },
  css: ['~/assets/css/main.css'],
  supabase: {
    // redirect: false
    redirectOptions: {
      login: '/admin/login',
      callback: '/admin',
      include: ['/admin(/*)?'],
    }
  },
  site: {
    url: 'https://vaxtlistan.se',
    name: 'Växtlistan - Hitta växter hos svenska plantskolor'
  },
  sitemap: {
    sources: [
      '/api/sitemap-plants',
      '/api/sitemap-plantskolor'
    ],
    urls: [
      {
        loc: '/',
        changefreq: 'monthly',
        priority: 0.6
      },
      {
        loc: '/vaxt/s',
        changefreq: 'monthly',
        priority: 0.2
      },
      {
        loc: '/plantskolor',
        changefreq: 'weekly',
        priority: 0.8
      },
      {
        loc: '/for-plantskolor',
        changefreq: 'monthly',
        priority: 0.7
      },
      {
        loc: '/om-oss',
        changefreq: 'monthly',
        priority: 0.6
      }
    ]
  },
  runtimeConfig: {
    public: {
      LINDERSPLANTSKOLA_SUPABASE_URL: process.env.LINDERSPLANTSKOLA_SUPABASE_URL,
      LINDERSPLANTSKOLA_SUPABASE_KEY: process.env.LINDERSPLANTSKOLA_SUPABASE_KEY,
      siteUrl: 'https://vaxtlistan.se',
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