import type { Facit, AvailablePlantSearchResult, AvailablePlantSimilaritySearchResult, EnhancedPlantSearchResult } from '~/types/supabase-tables';

export interface SearchResult {
  results: Facit[];
  totalCount: number;
  searchTime: number;
}

export interface EnhancedSearchResult {
  results: EnhancedPlantSearchResult[];
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
  plantType?: string; // Filter by plant type (träd, buskar, etc.)
}

export interface InlineSearchResult {
  id: number;
  name: string;
  sv_name: string | null;
  type: string;
}

/**
 * Result interface for strict match search (import validation)
 */
export interface StrictMatchResult {
  id: number;
  name: string;
  sv_name: string | null;
  similarity_score: number;
  is_exact_match: boolean;
  match_type: string; // 'name' or 'sv_name'
}

/**
 * Result interface for fuzzy match search (import suggestions)
 */
export interface FuzzyMatchResult {
  id: number;
  name: string;
  sv_name: string | null;
  similarity_score: number;
  match_details: string; // JSON string with match information
  suggested_reason: string; // Why this plant is suggested
}

export const useSearch = () => {
  const supabase = useSupabaseClient();

  /**
   * Main plant search using the optimized search_plants_main_page function
   * Features fuzzy matching, relevance scoring, analytics, and plant type filtering
   */
  const searchPlants = async (
    query: string,
    options: SearchOptions = {}
  ): Promise<AvailableSearchResult> => {
    const startTime = performance.now();
    const { limit = 60, offset = 0, includeCount = true, plantType } = options;

    // Sanitize and validate query
    const sanitizedQuery = query.trim();
    if (sanitizedQuery.length < 2) {
      return {
        results: [],
        totalCount: 0,
        searchTime: performance.now() - startTime,
      };
    }

    try {      // Use the new optimized search_plants_main_page function
      const { data, error } = await supabase.rpc('search_plants_main_page', {
        search_term: sanitizedQuery,
        filters: plantType ? JSON.stringify({ plant_types: [plantType] }) : '{}',
        include_hidden: false,
        result_limit: limit,
        offset_param: offset,
      } as any);

      if (error) {
        console.error('Main plant search RPC error:', error);
        throw error;
      }      const results = (data as any[]) || [];
      const searchTime = performance.now() - startTime;

      // Get total count from the first result if available (returned by the function)
      const totalCount = includeCount && results.length > 0 ? (results[0] as any).total_results || 0 : 0;

      return {
        results,
        totalCount,
        searchTime,
      };
    } catch (error) {
      console.error('Main plant search error:', error);
      const searchTime = performance.now() - startTime;
      return {
        results: [],
        totalCount: 0,
        searchTime,
      };
    }
  };

  /**
   * Fast inline search for autocomplete and navigation
   * Uses the optimized search_inline function with both plant and nursery results
   */
  const searchInline = async (
    query: string,
    limit: number = 10
  ): Promise<InlineSearchResult[]> => {
    const sanitizedQuery = query.trim();
    if (sanitizedQuery.length < 2) {
      return [];
    }

    try {      // Use the new optimized search_inline function
      const { data, error } = await supabase.rpc('search_inline', {
        search_term: sanitizedQuery,
        result_limit: limit,
      } as any);

      if (error || !data) {
        console.error('Inline search RPC error:', error);
        return [];
      }      return (data as any[]).map((item: any) => ({
        id: item.id,
        name: item.name,
        sv_name: item.secondary_name,
        type: item.result_type, // 'plant' or 'plantskola'
      }));
    } catch (error) {
      console.error('Inline search error:', error);
      return [];
    }
  };

  /**
   * Legacy function for backward compatibility - now uses the main search function
   */
  const searchAvailablePlants = async (
    query: string,
    options: SearchOptions = {}
  ): Promise<AvailableSearchResult> => {
    return searchPlants(query, options);
  };  /**
   * Search ALL plants in facit table (170k+ rows) - for PlantPicker component
   * Uses the redesigned search_all_plants SQL function with advanced trigram similarity matching
   * Features: fuzzy matching, synonym splitting, similarity scoring, matched synonym detection
   */
  const searchAllPlants = async (
    query: string,
    options: SearchOptions & { minimumSimilarity?: number } = {}
  ): Promise<EnhancedSearchResult> => {
    const startTime = performance.now();
    const { limit = 50, minimumSimilarity = 0.25 } = options;

    // Sanitize and validate query
    const sanitizedQuery = query.trim();
    if (sanitizedQuery.length < 2) {
      return {
        results: [],
        totalCount: 0,
        searchTime: performance.now() - startTime,
      };
    }

    try {
      // Use the redesigned search_all_plants function with trigram similarity
      const { data, error } = await supabase.rpc('search_all_plants', {
        search_term: sanitizedQuery,
        result_limit: limit,
        minimum_similarity: minimumSimilarity,
      } as any);

      if (error) {
        console.error('Enhanced search ALL plants RPC error:', error);
        throw error;
      }

      const searchTime = performance.now() - startTime;
      const results = (data as any[]) || [];

      return {
        results: results.map((item: any) => ({
          // Map all Facit fields
          id: item.id,
          created_at: item.created_at || new Date().toISOString(),
          name: item.name,
          sv_name: item.sv_name,
          is_recommended: item.is_recommended,
          is_original: item.is_original,
          is_synonym: item.is_synonym,
          synonym_to: item.synonym_to,
          synonym_to_id: item.synonym_to_id,
          has_synonyms: item.has_synonyms,
          has_synonyms_id: item.has_synonyms_id,
          taxonomy_type: item.taxonomy_type,
          plant_type: item.plant_type,
          spread: item.spread,
          height: item.height,
          rhs_id: item.rhs_id,
          sunlight: item.sunlight,
          soil_type: item.soil_type,
          full_height_time: item.full_height_time,
          moisture: item.moisture,
          ph: item.ph,
          exposure: item.exposure,
          season_of_interest: item.season_of_interest,
          colors: item.colors,
          rhs_types: item.rhs_types,
          user_submitted: item.user_submitted,
          created_by: item.created_by,
          last_edited: item.last_edited,
          // Enhanced search fields
          similarity_score: item.similarity_score || 0,
          matched_synonym: item.matched_synonym || null,
        } as EnhancedPlantSearchResult)),
        totalCount: results.length, // For now, don't do separate count query for performance
        searchTime,
      };
    } catch (error) {
      console.error('Enhanced search ALL plants function error:', error);
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
   */
  const fuzzySearchPlants = async (
    query: string,
    options: SearchOptions = {}
  ): Promise<SearchResult> => {
    // Convert AvailableSearchResult to SearchResult for backward compatibility
    const result = await searchPlants(query, options);
    
    // Map AvailablePlantSearchResult to Facit for backward compatibility
    const facitResults: Facit[] = result.results.map((item: any) => {
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
   * Lightning-fast autocomplete search - now uses the inline search function
   */
  const searchPlantsAutocomplete = async (
    query: string,
    limit: number = 10
  ): Promise<{ name: string; sv_name: string | null }[]> => {
    const results = await searchInline(query, limit);
    
    // Filter for plants only and map to the expected format
    return results
      .filter(item => item.type === 'plant')
      .map(item => ({
        name: item.name,
        sv_name: item.sv_name,
      }));
  };

  /**
   * Strict match search for import validation
   * Uses the search_plants_strict_match function to find exact or near-exact matches
   */
  const searchPlantsStrictMatch = async (
    query: string,
    minimumSimilarity: number = 0.8
  ): Promise<StrictMatchResult[]> => {
    const sanitizedQuery = query.trim();
    if (sanitizedQuery.length < 2) {
      return [];
    }    try {
      const { data, error } = await supabase.rpc('search_plants_strict_match', {
        p_search_term: sanitizedQuery,
        p_minimum_similarity: minimumSimilarity,
      } as any);

      if (error) {
        console.error('Strict match search RPC error:', error);
        throw error;
      }

      return (data as any[])?.map((item: any) => ({
        id: item.id,
        name: item.name,
        sv_name: item.sv_name,
        similarity_score: item.similarity_score,
        is_exact_match: item.is_exact_match,
        match_type: item.match_type,
      })) || [];
    } catch (error) {
      console.error('Strict match search error:', error);
      return [];
    }
  };

  /**
   * Fuzzy match search for import suggestions ("menade du?")
   * Uses the search_plants_fuzzy_match function to find similar plants when strict match fails
   */
  const searchPlantsFuzzyMatch = async (
    query: string,
    limit: number = 10,
    minimumSimilarity: number = 0.3
  ): Promise<FuzzyMatchResult[]> => {
    const sanitizedQuery = query.trim();
    if (sanitizedQuery.length < 2) {
      return [];
    }    try {
      const { data, error } = await supabase.rpc('search_plants_fuzzy_match', {
        p_search_term: sanitizedQuery,
        p_result_limit: limit,
        p_minimum_similarity: minimumSimilarity,
      } as any);

      if (error) {
        console.error('Fuzzy match search RPC error:', error);
        throw error;
      }

      return (data as any[])?.map((item: any) => ({
        id: item.id,
        name: item.name,
        sv_name: item.sv_name,
        similarity_score: item.similarity_score,
        match_details: item.match_details,
        suggested_reason: item.suggested_reason,
      })) || [];
    } catch (error) {
      console.error('Fuzzy match search error:', error);
      return [];
    }
  };

  return {
    searchPlants, // Main search function - uses new optimized SQL
    searchAvailablePlants, // Legacy alias for searchPlants
    searchAllPlants, // For PlantPicker - searches all plants in facit
    searchInline, // New fast inline search for autocomplete
    fuzzySearchPlants, // Legacy function
    searchPlantsAutocomplete, // Legacy autocomplete function
    searchPlantsStrictMatch, // New strict match search for import validation
    searchPlantsFuzzyMatch, // New fuzzy match search for import suggestions
  };
};