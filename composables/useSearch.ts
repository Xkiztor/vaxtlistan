import type { Facit } from '~/types/supabase-tables';

export interface SearchResult {
  results: Facit[];
  totalCount: number;
  searchTime: number;
}

export interface SearchOptions {
  limit?: number;
  offset?: number;
  includeCount?: boolean;
}

export const useSearch = () => {
  const supabase = useSupabaseClient();

  /**
   * Ultra-high-performance search optimized for 170k+ rows on free Supabase tier
   * Uses custom PostgreSQL functions with proper indexing
   */
  const searchPlants = async (
    query: string,
    options: SearchOptions = {}
  ): Promise<SearchResult> => {
    const startTime = performance.now();
    const { limit = 60, offset = 0, includeCount = true } = options;

    // Sanitize and validate query
    const sanitizedQuery = query.trim().toLowerCase();
    if (sanitizedQuery.length < 2) {
      return {
        results: [],
        totalCount: 0,
        searchTime: performance.now() - startTime,
      };
    }

    try {
      // Choose optimal search strategy based on query length
      const usePrefix = sanitizedQuery.length <= 4; // Prefix search is fastest for short queries
      
      // Call the optimized PostgreSQL function
      const functionName = usePrefix ? 'search_plants_prefix' : 'search_plants_substring';
      
      const { data, error } = await supabase.rpc(functionName, {
        search_term: sanitizedQuery,
        result_limit: limit,
        result_offset: offset,
      });

      if (error) {
        console.error('Search RPC error:', error);
        throw error;
      }

      // Get total count efficiently (only on first page)
      let totalCount = 0;
      if (includeCount && offset === 0) {
        const { data: countData, error: countError } = await supabase.rpc('count_search_results', {
          search_term: sanitizedQuery,
          use_prefix: usePrefix,
        });

        if (!countError && typeof countData === 'number') {
          totalCount = countData;
        }
      }

      const searchTime = performance.now() - startTime;

      return {
        results: data || [],
        totalCount,
        searchTime,
      };
    } catch (error) {
      console.error('Search function error:', error);
      const searchTime = performance.now() - startTime;
      return {
        results: [],
        totalCount: 0,
        searchTime,
      };
    }
  };

  /**
   * Advanced similarity search using pg_trgm (use only when needed)
   * More resource-intensive but handles typos and fuzzy matching
   */
  const fuzzySearchPlants = async (
    query: string,
    options: SearchOptions = {}
  ): Promise<SearchResult> => {
    const startTime = performance.now();
    const { limit = 60, offset = 0, includeCount = true } = options;

    const sanitizedQuery = query.trim().toLowerCase();
    if (sanitizedQuery.length < 3) {
      // Fall back to regular search for short queries
      return searchPlants(query, options);
    }

    try {
      // Use trigram similarity search for fuzzy matching
      const { data, error } = await supabase.rpc('search_plants_similarity', {
        search_term: sanitizedQuery,
        similarity_threshold: 0.3,
        result_limit: limit,
        result_offset: offset,
      });

      if (error) {
        console.error('Fuzzy search RPC error:', error);
        // Fall back to regular search on error
        return searchPlants(query, options);
      }

      // Count is expensive for similarity search, so we estimate
      let totalCount = 0;
      if (includeCount && offset === 0 && data) {
        // Estimate based on returned results
        totalCount = data.length < limit ? data.length : data.length * 2;
      }

      const searchTime = performance.now() - startTime;

      return {
        results: (data || []).map(item => {
          // Remove similarity_score from results to match Facit type
          const { similarity_score, ...facitItem } = item;
          return facitItem as Facit;
        }),
        totalCount,
        searchTime,
      };
    } catch (error) {
      console.error('Fuzzy search function error:', error);
      // Fall back to regular search
      return searchPlants(query, options);
    }
  };

  /**
   * Lightning-fast prefix search for autocomplete/suggestions
   * Optimized for real-time typing suggestions
   */
  const searchPlantsAutocomplete = async (
    query: string,
    limit: number = 10
  ): Promise<{ name: string; sv_name: string | null }[]> => {
    const sanitizedQuery = query.trim().toLowerCase();
    if (sanitizedQuery.length < 2) {
      return [];
    }

    try {
      const { data, error } = await supabase.rpc('search_plants_prefix', {
        search_term: sanitizedQuery,
        result_limit: limit,
        result_offset: 0,
      });

      if (error || !data) {
        return [];
      }

      return data.map(item => ({
        name: item.name,
        sv_name: item.sv_name,
      }));
    } catch (error) {
      console.error('Autocomplete search error:', error);
      return [];
    }
  };

  return {
    searchPlants,
    fuzzySearchPlants,
    searchPlantsAutocomplete,
  };
};