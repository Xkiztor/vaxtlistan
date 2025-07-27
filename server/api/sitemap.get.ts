import { createClient } from '@supabase/supabase-js'
import { defineSitemapEventHandler } from '#imports'
import type { SitemapUrlInput } from '#sitemap/types'

/**
 * Combined API endpoint to generate sitemap URLs for both plants and nurseries
 * Returns an array of URLs for the Nuxt sitemap module
 */
export default defineSitemapEventHandler(async (): Promise<SitemapUrlInput[]> => {
  try {
    // Initialize Supabase client with environment variables
    const supabaseUrl = useRuntimeConfig().public.SUPABASE_URL
    const supabaseKey = useRuntimeConfig().public.SUPABASE_KEY
    
    if (!supabaseUrl || !supabaseKey) {
      throw new Error('Supabase configuration missing')
    }

    const supabase = createClient(supabaseUrl, supabaseKey)

    // Execute both SQL queries in parallel for better performance
    const [plantsResult, nurseriesResult] = await Promise.all([
      supabase.rpc('get_available_plants_sitemap'),
      supabase.rpc('get_plantskolor_sitemap')
    ])

    const sitemapUrls: SitemapUrlInput[] = []

    // Process plants data
    if (plantsResult.error) {
      console.error('Plants database error:', plantsResult.error)
    } else if (plantsResult.data && plantsResult.data.length > 0) {
      const plantUrls = plantsResult.data.map((plant: any) => {
        // URL encode the plant name for safe URL generation
        // Encode plant name for URL, replacing spaces with hyphens for better SEO
        const encodedName = encodeURIComponent(plant.name.replace(/\s+/g, '-'))
        // const encodedName = encodeURIComponent(plant.name)
        
        // Format last modified date
        const lastmod = plant.last_edited 
          ? new Date(plant.last_edited).toISOString()
          : new Date().toISOString()

        return {
          loc: `/vaxt/${plant.id}/${encodedName}`,
          lastmod: lastmod,
          changefreq: 'weekly',
          priority: 0.8,
          _sitemap: 'pages'
        }
      })
      
      sitemapUrls.push(...plantUrls)
    } else {
      console.warn('No plants found for sitemap')
    }

    // Process nurseries data
    if (nurseriesResult.error) {
      console.error('Nurseries database error:', nurseriesResult.error)
    } else if (nurseriesResult.data && nurseriesResult.data.length > 0) {
      const nurseryUrls = nurseriesResult.data.map((nursery: any) => {
        // Format last modified date
        const lastmod = nursery.last_edited 
          ? new Date(nursery.last_edited).toISOString()
          : new Date().toISOString()

        return {
          loc: `/plantskola/${nursery.id}`,
          lastmod: lastmod,
          changefreq: 'weekly',
          priority: 0.7,
          _sitemap: 'pages'
        }
      })
      
      sitemapUrls.push(...nurseryUrls)
    } else {
      console.warn('No nurseries found for sitemap')
    }

    console.log(`Generated sitemap with ${sitemapUrls.length} URLs (${plantsResult.data?.length || 0} plants, ${nurseriesResult.data?.length || 0} nurseries)`)
    
    return sitemapUrls

  } catch (error) {
    console.error('Sitemap generation error:', error)
    
    // Return empty array on error to prevent sitemap generation failure
    return []
  }
})
