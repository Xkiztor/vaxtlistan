import { createClient } from '@supabase/supabase-js'

/**
 * API endpoint to generate sitemap URLs for available plants
 * Returns an array of URLs for the Nuxt sitemap module
 */
export default defineEventHandler(async (event) => {
  try {
    // Initialize Supabase client with environment variables
    const supabaseUrl = useRuntimeConfig().public.LINDERSPLANTSKOLA_SUPABASE_URL
    const supabaseKey = useRuntimeConfig().public.LINDERSPLANTSKOLA_SUPABASE_KEY
    
    if (!supabaseUrl || !supabaseKey) {
      throw new Error('Supabase configuration missing')
    }

    const supabase = createClient(supabaseUrl, supabaseKey)

    // Execute the SQL query to get available plants
    const { data: plants, error } = await supabase.rpc('get_available_plants_sitemap')

    if (error) {
      console.error('Database error:', error)
      throw new Error('Failed to fetch plants from database')
    }

    if (!plants || plants.length === 0) {
      console.warn('No plants found for sitemap')
      return []
    }

    // Get the site URL from runtime config
    const siteUrl = useRuntimeConfig().public.siteUrl

    // Generate sitemap URLs array for Nuxt sitemap module
    const sitemapUrls = plants.map((plant: any) => {
      // URL encode the plant name for safe URL generation
      const encodedName = encodeURIComponent(plant.name)
      
      // Format last modified date
      const lastmod = plant.last_edited 
        ? new Date(plant.last_edited).toISOString()
        : new Date().toISOString()

      return {
        loc: `/vaxt/${plant.id}/${encodedName}`,
        lastmod: lastmod,
        changefreq: 'weekly',
        priority: 0.8
      }
    })

    // Set caching headers
    setHeader(event, 'Cache-Control', 'public, max-age=3600') // Cache for 1 hour
    
    return sitemapUrls

  } catch (error) {
    console.error('Sitemap generation error:', error)
    
    // Return empty array on error to prevent sitemap generation failure
    return []
  }
})
