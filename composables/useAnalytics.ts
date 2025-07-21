/**
 * Analytics composable for tracking plant page views and popularity
 * 
 * This composable provides functionality to:
 * - Track plant page views for popularity scoring
 * - Handle errors gracefully without breaking user experience
 * - Work with the plant popularity system
 */

export const useAnalytics = () => {
  const supabase = useSupabaseClient();

  /**
   * Track a plant page view for popularity analytics
   * 
   * @param facitId - The ID of the plant from the facit table
   * @returns Promise<void>
   */
  const trackPlantView = async (facitId: number): Promise<void> => {
    try {
      // Validate input
      if (!facitId || typeof facitId !== 'number' || facitId <= 0) {
        console.warn('Invalid facit_id provided to trackPlantView:', facitId);
        return;
      }

      // Call the database function to track the view
      const { error } = await supabase.rpc('track_plant_view', {
        p_facit_id: facitId
      });

      if (error) {
        console.warn('Analytics tracking failed:', error.message);
        // Don't throw error - analytics failure shouldn't break the app
        return;
      }

      // Success - no need to log in production
      if (process.dev) {
        console.log(`Successfully tracked view for plant ${facitId}`);
      }
    } catch (error) {
      console.warn('Analytics tracking error:', error);
      // Analytics should never break the user experience
    }
  };

  /**
   * Get popularity statistics (for admin/monitoring purposes)
   * 
   * @returns Promise with popularity statistics or null if error
   */
  const getPopularityStats = async () => {
    try {
      const { data, error } = await supabase.rpc('get_popularity_statistics');
      
      if (error) {
        console.error('Failed to get popularity statistics:', error);
        return null;
      }

      return data?.[0] || null;
    } catch (error) {
      console.error('Error fetching popularity statistics:', error);
      return null;
    }
  };

  /**
   * Track multiple plant views (for batch operations)
   * 
   * @param facitIds - Array of plant IDs to track
   */
  const trackMultiplePlantViews = async (facitIds: number[]): Promise<void> => {
    // Track views in parallel but don't wait for all to complete
    const promises = facitIds
      .filter(id => id && typeof id === 'number' && id > 0)
      .map(id => trackPlantView(id));
    
    // Fire and forget - don't await all promises
    Promise.allSettled(promises).catch(() => {
      // Silently handle any errors
    });
  };

  return {
    trackPlantView,
    getPopularityStats,
    trackMultiplePlantViews
  };
};
