// server/api/batch-add-images.post.ts
import { createClient } from '@supabase/supabase-js';
import type { H3Event } from 'h3';

// Type for plants without images from totallager (plants available in nurseries)
interface PlantWithoutImages {
  id: number;
  name: string;
}

// Type for the Google Custom Search API image result (reused from image-search.get.ts)
interface GoogleImageItem {
  link: string;
  title: string;
  image: {
    contextLink: string;
    thumbnailLink: string;
  };
}

interface GoogleImageSearchResponse {
  items: GoogleImageItem[];
}

interface ImageObject {
  url: string;
  title: string;
  sourcePage: string;
}

export default defineEventHandler(async (event: H3Event) => {
  // Only allow POST requests
  if (event.method !== 'POST') {
    throw createError({
      statusCode: 405,
      statusMessage: 'Method Not Allowed'
    });
  }

  // Get request body
  const body = await readBody(event);
  const { count = 10 } = body;

  // Validate count parameter
  if (!count || isNaN(count) || count <= 0 || count > 100) {
    throw createError({
      statusCode: 400,
      statusMessage: 'Invalid count parameter. Must be between 1 and 100.'
    });
  }

  // Initialize Supabase client
  const supabaseUrl = useRuntimeConfig().public.SUPABASE_URL;
  const supabaseKey = useRuntimeConfig().public.SUPABASE_KEY;
  
  if (!supabaseUrl || !supabaseKey) {
    throw createError({
      statusCode: 500,
      statusMessage: 'Supabase configuration missing'
    });
  }

  const supabase = createClient(supabaseUrl, supabaseKey);

  // Get API keys for Google Image Search
  const apiKey = process.env.GOOGLE_SEARCH_API_KEY;
  const cx = process.env.GOOGLE_CSE_ID;

  if (!apiKey || !cx) {
    throw createError({
      statusCode: 500,
      statusMessage: 'Google Search API configuration missing'
    });
  }

  try {
    // First, get the facit_ids that exist in totallager
    const { data: totallagerFacitIds, error: totallagerError } = await supabase
      .from('totallager')
      .select('facit_id')
      .not('facit_id', 'is', null);

    if (totallagerError) {
      throw createError({
        statusCode: 500,
        statusMessage: `Database error fetching totallager: ${totallagerError.message}`
      });
    }

    if (!totallagerFacitIds || totallagerFacitIds.length === 0) {
      return {
        success: true,
        message: 'No plants found in totallager',
        processed: 0,
        results: []
      };
    }

    const facitIds = totallagerFacitIds.map(item => item.facit_id);

    // Get plants from facit that don't have images and are available in totallager
    // This ensures we only add images to plants that are actually sold by nurseries
    const { data: plantsWithoutImages, error: fetchError } = await supabase
      .from('facit')
      .select(`
        id, 
        name
      `)
      .is('images', null)
      .not('name', 'is', null)
      .in('id', facitIds)
      .order('name')
      .limit(count);

    if (fetchError) {
      throw createError({
        statusCode: 500,
        statusMessage: `Database error: ${fetchError.message}`
      });
    }

    if (!plantsWithoutImages || plantsWithoutImages.length === 0) {
      return {
        success: true,
        message: 'No plants without images found in totallager',
        processed: 0,
        results: []
      };
    }

    const results: Array<{
      plantId: number;
      plantName: string;
      success: boolean;
      imagesAdded: number;
      error?: string;
    }> = [];

    // Process each plant with a delay
    for (let i = 0; i < plantsWithoutImages.length; i++) {
      const plant = plantsWithoutImages[i];
      
        try {
          // Search for images using Google Custom Search API
          const searchResponse = await $fetch<GoogleImageSearchResponse>(
            'https://www.googleapis.com/customsearch/v1',
            {
              params: {
                key: apiKey,
                cx: cx,
                searchType: 'image',
                q: `${plant.name} plant flower`,  // Add keywords to improve search results
                num: 10,
                start: 1,
                safe: 'active', // Enable safe search
                imgType: 'photo', // Prefer photos over clipart
              },
              timeout: 3000, // 3 second timeout
            }
          );        if (searchResponse.items && searchResponse.items.length > 0) {
          // Convert Google results to our image format
          const images: ImageObject[] = searchResponse.items
            .filter((item: GoogleImageItem) => item.link && item.link.startsWith('http')) // Only valid URLs
            .map((item: GoogleImageItem) => ({
              url: item.link,
              title: item.title || '',
              sourcePage: item.image?.contextLink || item.link,
            }))

          if (images.length > 0) {
            // Update the plant with the found images
            const now = new Date().toISOString();
            const { error: updateError } = await supabase
              .from('facit')
              .update({
                images: images,
                images_reordered: false,
                images_added_date: now,
              })
              .eq('id', plant.id);

            if (updateError) {
              results.push({
                plantId: plant.id,
                plantName: plant.name,
                success: false,
                imagesAdded: 0,
                error: `Update failed: ${updateError.message}`,
              });
            } else {
              results.push({
                plantId: plant.id,
                plantName: plant.name,
                success: true,
                imagesAdded: images.length,
              });
            }
          } else {
            results.push({
              plantId: plant.id,
              plantName: plant.name,
              success: false,
              imagesAdded: 0,
              error: 'No valid images found',
            });
          }
        } else {
          results.push({
            plantId: plant.id,
            plantName: plant.name,
            success: false,
            imagesAdded: 0,
            error: 'No images found',
          });
        }
      } catch (searchError: any) {
        results.push({
          plantId: plant.id,
          plantName: plant.name,
          success: false,
          imagesAdded: 0,
          error: `Search failed: ${searchError.message || 'Unknown error'}`,
        });
      }

      // Add delay between requests to avoid overwhelming the API
      // Skip delay for the last item
      if (i < plantsWithoutImages.length - 1) {
        await new Promise(resolve => setTimeout(resolve, 1000)); // 1 second delay
      }
    }

    const successful = results.filter(r => r.success).length;
    const totalImages = results.reduce((sum, r) => sum + r.imagesAdded, 0);

    return {
      success: true,
      message: `Processed ${plantsWithoutImages.length} plants from totallager. ${successful} successful, ${totalImages} images added.`,
      processed: plantsWithoutImages.length,
      successful,
      totalImages,
      results,
    };

  } catch (error: any) {
    throw createError({
      statusCode: 500,
      statusMessage: `Batch processing failed: ${error.message || 'Unknown error'}`
    });
  }
});
