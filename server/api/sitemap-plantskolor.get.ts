import { createClient } from '@supabase/supabase-js'

/**
 * API endpoint to generate sitemap URLs for verified nurseries
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

    // Execute the SQL query to get verified nurseries
    const { data: nurseries, error } = await supabase.rpc('get_plantskolor_sitemap')

    if (error) {
      console.error('Database error:', error)
      throw new Error('Failed to fetch nurseries from database')
    }

    if (!nurseries || nurseries.length === 0) {
      console.warn('No nurseries found for sitemap')
      return []
    }

    // Generate sitemap URLs array for Nuxt sitemap module
    const sitemapUrls = nurseries.map((nursery: any) => {
      // Format last modified date
      const lastmod = nursery.last_edited 
        ? new Date(nursery.last_edited).toISOString()
        : new Date().toISOString()

      return {
        loc: `/plantskola/${nursery.id}`,
        lastmod: lastmod,
        changefreq: 'weekly',
        priority: 0.7
      }
    })

    // Set caching headers
    setHeader(event, 'Cache-Control', 'public, max-age=3600') // Cache for 1 hour
    
    return sitemapUrls

  } catch (error) {
    console.error('Nursery sitemap generation error:', error)
    
    // Return empty array on error to prevent sitemap generation failure
    return []
  }
})
