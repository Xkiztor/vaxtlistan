import type { Facit, AvailablePlantSearchResult, AvailablePlantSimilaritySearchResult } from '~/types/supabase-tables';

export interface SearchResult {
  results: Facit[];
  totalCount: number;
  searchTime: number;
}

export interface AvailableSearchResult {
  results: AvailablePlantSimilaritySearchResult[];
  totalCount: number;
  searchTime: number;
}

export interface SearchOptions {
  limit?: number;
  offset?: number;
  includeCount?: boolean;
  includeHidden?: boolean;
}

export const useSearch = () => {
  const supabase = useSupabaseClient();

  /**
   * Search ALL plants in facit table (170k+ rows)
   * Used by PlantPicker for adding new plants to lager
   */
  const searchAllPlants = async (
    query: string,
    options: SearchOptions = {}
  ): Promise<SearchResult> => {
    const startTime = performance.now();
    const { limit = 50, offset = 0, includeCount = true } = options;

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
        // Call the optimized PostgreSQL function for ALL plants
      const functionName = usePrefix ? 'search_all_plants_prefix' : 'search_all_plants_substring';
      
      const { data, error } = await supabase.rpc(functionName, {
        search_term: sanitizedQuery,
        result_limit: limit,
        result_offset: offset,
      } as any);

      if (error) {
        console.error('Search ALL plants RPC error:', error);
        throw error;
      }

      // Get total count efficiently (only on first page)
      let totalCount = 0;
      if (includeCount && offset === 0) {
        const { data: countData, error: countError } = await supabase.rpc('count_all_plants_search_results', {
          search_term: sanitizedQuery,
          use_prefix: usePrefix,
        } as any);

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
      console.error('Search ALL plants function error:', error);
      const searchTime = performance.now() - startTime;
      return {
        results: [],
        totalCount: 0,
        searchTime,
      };
    }
  };

  /**
   * Search AVAILABLE plants only (plants in totallager)
   * Used by search page and inline search - much faster and more relevant
   */
  const searchAvailablePlants = async (
    query: string,
    options: SearchOptions = {}
  ): Promise<AvailableSearchResult> => {
    const startTime = performance.now();
    const { limit = 60, offset = 0, includeCount = true, includeHidden = false } = options;

    // Sanitize and validate query
    const sanitizedQuery = query.trim().toLowerCase();
    if (sanitizedQuery.length < 2) {
      return {
        results: [],
        totalCount: 0,
        searchTime: performance.now() - startTime,
      };
    }    try {
      // For available plants, use fuzzy search by default since the dataset is much smaller
      // This provides better search quality for typos and similar terms
      const { data, error } = await supabase.rpc('search_available_plants', {
        search_term: sanitizedQuery,
        result_limit: limit,
        result_offset: offset,
        include_hidden: includeHidden,
        use_fuzzy: true, // Default to fuzzy search for better UX
      } as any);

      if (error) {
        console.error('Search AVAILABLE plants RPC error:', error);
        throw error;
      }

      // Get total count efficiently (only on first page)
      let totalCount = 0;
      if (includeCount && offset === 0) {
        const { data: countData, error: countError } = await supabase.rpc('count_available_plants_search_results', {
          search_term: sanitizedQuery,
          use_prefix: false, // Count using the same strategy as main search
          include_hidden: includeHidden,
        } as any);

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
      console.error('Search AVAILABLE plants function error:', error);
      const searchTime = performance.now() - startTime;
      return {
        results: [],
        totalCount: 0,
        searchTime,
      };
    }
  };

  /**
   * Legacy function for backward compatibility
   * Now defaults to searching available plants for better performance and relevance
   */
  const searchPlants = async (
    query: string,
    options: SearchOptions = {}
  ): Promise<SearchResult> => {
    // Convert AvailableSearchResult to SearchResult for backward compatibility
    const result = await searchAvailablePlants(query, options);
      // Map AvailablePlantSearchResult to Facit for backward compatibility
    const facitResults: Facit[] = result.results.map(item => {
      const { available_count, plantskolor_count, prices, similarity_score, ...facitItem } = item;
      return {
        ...facitItem,
        created_at: '', // Add required field with default value
      } as Facit;
    });

    return {
      results: facitResults,
      totalCount: result.totalCount,
      searchTime: result.searchTime,
    };
  };  /**
   * Advanced similarity search using pg_trgm (now integrated into main search)
   * More resource-intensive but handles typos and fuzzy matching
   */
  const fuzzySearchPlants = async (
    query: string,
    options: SearchOptions = {}
  ): Promise<SearchResult> => {
    // Since fuzzy search is now the default for searchAvailablePlants,
    // we can just use that function
    const result = await searchAvailablePlants(query, options);
    
    // Convert to SearchResult format for backward compatibility
    const facitResults: Facit[] = result.results.map(item => {
      const { available_count, plantskolor_count, prices, similarity_score, ...facitItem } = item;
      return {
        ...facitItem,
        created_at: '', // Add required field with default value
      } as Facit;
    });

    return {
      results: facitResults,
      totalCount: result.totalCount,
      searchTime: result.searchTime,
    };
  };

  /**
   * Lightning-fast prefix search for autocomplete/suggestions
   * Optimized for real-time typing suggestions - uses available plants only
   */
  const searchPlantsAutocomplete = async (
    query: string,
    limit: number = 10
  ): Promise<{ name: string; sv_name: string | null }[]> => {
    const sanitizedQuery = query.trim().toLowerCase();
    if (sanitizedQuery.length < 2) {
      return [];
    }    try {
      // Use the main available plants search for autocomplete too
      const { data, error } = await supabase.rpc('search_available_plants', {
        search_term: sanitizedQuery,
        result_limit: limit,
        result_offset: 0,
        include_hidden: false,
        use_fuzzy: false, // Use faster search for autocomplete
      } as any);

      if (error || !data) {
        return [];
      }

      return (data as any[]).map((item: any) => ({
        name: item.name,
        sv_name: item.sv_name,
      }));
    } catch (error) {
      console.error('Autocomplete search error:', error);
      return [];
    }
  };

  return {
    searchPlants, // Legacy function - now searches available plants
    searchAllPlants, // New function for PlantPicker - searches all plants
    searchAvailablePlants, // New function for search page - searches available plants only
    fuzzySearchPlants,
    searchPlantsAutocomplete,
  };
};