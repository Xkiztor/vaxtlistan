/**
 * Plant Name Similarity Calculator
 * 
 * This composable provides client-side plant name similarity calculation
 * for matching imported plant names to the facit database. It integrates with
 * the SQL RPC function `plants_match` for candidate selection and provides
 * component-based scoring.
 * 
 * KEY FEATURES:
 * - Weighted similarity scoring using genus, sortBrandName, and fullName components
 * - Interchangeable matching between sortName and brandName (cultivar names)
 * - Integration with plants_match RPC function for candidate selection
 * - Support for main names, Swedish names (sv_name), and synonyms
 * 
 * COMPONENT SCORING:
 * - genus (42%): Taxonomic accuracy - first word comparison
 * - sortBrandName (42%): Commercial/cultivar names - cross-matching between
 *   sortName (single quotes) and brandName (all caps) components
 * - fullName (16%): Overall string similarity for the complete name
 * 
 * USAGE:
 * ```typescript
 * const { findBestMatches } = usePlantSimilarity();
 * 
 * // Find matches for imported plant names
 * const result = await findBestMatches("Rosa gallica 'Charles de Mills'");
 * ```
 */

import { compareTwoStrings } from 'string-similarity';
import type { Facit, PlantSearchResult } from '~/types/supabase-tables';



/**
 * Interface for plant name components extracted from a full plant name
 */
interface PlantNameComponents {
  genus: string; // First word (e.g., "Rosa")
  species: string; // Second word if exists (e.g., "gallica")
  sortName: string; // Text surrounded by single quotes (e.g., "'Charles de Mills'")
  brandName: string; // Text in all caps (e.g., "KNOCKOUT")
  cultivar: string; // Text in double quotes (e.g., "Double Delight")
  remaining: string; // Everything else
  fullName: string; // Complete original name
}

/**
 * Interface for detailed similarity calculation result
 */
interface ComponentMatchResult {
  searchValue: string;
  plantValue: string;
  score: number;
}

/**
 * Interface for similarity calculation result
 */
interface SimilarityResult {
  id: number;
  name: string;
  sv_name?: string | null;
  plant_type?: string | null;
  grupp?: string | null;
  serie?: string | null;
  totalScore: number;
  isStrictMatch: boolean; // True if totalScore >= 0.95
  componentScores: {
    genus: ComponentMatchResult;
    species: ComponentMatchResult;
    sortBrandName: ComponentMatchResult;
    fullName: ComponentMatchResult;
  };
  bestMatchSource: 'main_name' | 'sv_name' | 'synonym';
  matchDetails: string; // JSON string with detailed match information
}

/**
 * Interface for similarity calculation weights
 */
interface SimilarityWeights {
  genus: number; // High priority for first word
  species: number; // Medium priority for second word (species)
  sortBrandName: number; // High priority for quoted names and brand names (treated as interchangeable)
  fullName: number; // Medium priority for complete name match
}

/**
 * Default weights for different parts of plant names
 */
const DEFAULT_WEIGHTS: SimilarityWeights = {
  genus: 0.35,
  species: 0.10, 
  sortBrandName: 0.40, 
  fullName: 0.15,
};

/**
 * Similarity calculator with comprehensive logging and improved algorithms
 */
export const usePlantSimilarity = () => {  /**
   * Simple logger for plant matches
   */
  const logMatches = (searchQuery: string, results: SimilarityResult[]) => {
    if (results.length === 0) {
      console.log(`No matches found for: "${searchQuery}"`);
      return;
    }
    
    console.log(`\n=== PLANT MATCHES FOR: "${searchQuery}" ===`);
    
    results.forEach((result, index) => {
      const score = (result.totalScore * 100).toFixed(1);
      const type = result.isStrictMatch ? 'EXACT' : 'SIMILAR';
      
      console.log(`${index + 1}. ${result.name} - ${score}% (${type})`);
      
      // Show what it matched on
      if (result.bestMatchSource === 'sv_name') {
        console.log(`  Matched on Swedish name: ${result.sv_name}`);
      } else if (result.bestMatchSource === 'synonym') {
        console.log(`  Matched on synonym`);
      } else {
        console.log(`  Matched on plant name`);
      }
      
      console.log('');
    });
    
    console.log(`=== END MATCHES ===\n`);
  };
  /**
   * Enhanced plant name parser
   */
  const parseStandablantName = (name: string): PlantNameComponents => {
    if (!name || typeof name !== 'string') {
      return {
        genus: '',
        species: '',
        sortName: '',
        brandName: '',
        cultivar: '',
        remaining: '',
        fullName: '',
      };
    }

    const originalName = name.trim();
    let workingName = originalName;

    // Extract sort name (text in single quotes)
    const sortNameMatch = workingName.match(/'([^']+)'/g);
    const sortName = sortNameMatch ? sortNameMatch.map(match => match.slice(1, -1)).join(' ') : '';
    if (sortName) {
      workingName = workingName.replace(/'[^']+'/g, '').trim();
    }

    // Extract cultivar (text in double quotes)
    const cultivarMatch = workingName.match(/"([^"]+)"/g);
    const cultivar = cultivarMatch ? cultivarMatch.map(match => match.slice(1, -1)).join(' ') : '';
    if (cultivar) {
      workingName = workingName.replace(/"[^"]+"/g, '').trim();
    }

    // Extract brand names (words in all caps with 3+ characters)
    const brandNameMatches = workingName.match(/\b[A-Z]{3,}(?:\s+[A-Z]{3,})*\b/g);
    const brandName = brandNameMatches ? brandNameMatches.join(' ') : '';
    if (brandName) {
      workingName = workingName.replace(/\b[A-Z]{3,}(?:\s+[A-Z]{3,})*\b/g, '').trim();
    }

    // Split remaining words
    const words = workingName.split(/\s+/).filter(word => word.length > 0);
    const genus = words[0] || '';
    const species = words[1] || '';
    const remaining = words.slice(2).join(' ');

    return {
      genus: genus.toLowerCase(),
      species: species.toLowerCase(),
      sortName: sortName.toLowerCase(),
      brandName: brandName.toLowerCase(),
      cultivar: cultivar.toLowerCase(),
      remaining: remaining.toLowerCase(),
      fullName: originalName.toLowerCase(),
    };
  };  /**
   * Enhanced component similarity calculation
   */
  const calculateComponentSimilarity = (
    searchComponents: PlantNameComponents,
    plantComponents: PlantNameComponents
  ): { genus: ComponentMatchResult; species: ComponentMatchResult; sortBrandName: ComponentMatchResult; fullName: ComponentMatchResult } => {
    // Calculate genus similarity
    const genusResult = calculateGenusMatch(searchComponents.genus, plantComponents.genus);
    
    // Calculate species similarity
    const speciesResult = calculateSpeciesMatch(searchComponents.species, plantComponents.species);
    
    // Calculate interchangeable sortName/brandName similarity
    const sortBrandResult = calculateSortBrandMatch(searchComponents, plantComponents);
    
    // Calculate full name similarity
    const fullNameResult = calculateFullNameMatch(searchComponents.fullName, plantComponents.fullName);

    return {
      genus: genusResult,
      species: speciesResult,
      sortBrandName: sortBrandResult,
      fullName: fullNameResult,
    };
  };  /**
   * Calculate genus matching
   */
  const calculateGenusMatch = (searchGenus: string, plantGenus: string): ComponentMatchResult => {
    if (!searchGenus || !plantGenus) {
      return {
        searchValue: searchGenus,
        plantValue: plantGenus,
        score: 0,
      };
    }

    const score = compareTwoStrings(searchGenus, plantGenus);

    return {
      searchValue: searchGenus,
      plantValue: plantGenus,
      score,
    };
  };  /**
   * Calculate species matching
   */
  const calculateSpeciesMatch = (searchSpecies: string, plantSpecies: string): ComponentMatchResult => {
    if (!searchSpecies || !plantSpecies) {
      return {
        searchValue: searchSpecies,
        plantValue: plantSpecies,
        score: 0,
      };
    }

    const score = compareTwoStrings(searchSpecies, plantSpecies);

    return {
      searchValue: searchSpecies,
      plantValue: plantSpecies,
      score,
    };
  };  /**
   * Calculate sortName/brandName cross-matching
   */
  const calculateSortBrandMatch = (
    searchComponents: PlantNameComponents,
    plantComponents: PlantNameComponents
  ): ComponentMatchResult => {
    const searchItems = [
      { value: searchComponents.sortName, type: 'sortName' },
      { value: searchComponents.brandName, type: 'brandName' },
    ].filter(item => item.value.length > 0);

    const plantItems = [
      { value: plantComponents.sortName, type: 'sortName' },
      { value: plantComponents.brandName, type: 'brandName' },
    ].filter(item => item.value.length > 0);

    if (searchItems.length === 0 && plantItems.length === 0) {
      return {
        searchValue: '',
        plantValue: '',
        score: 1, // No penalty if neither has sortName/brandName
      };
    }

    if (searchItems.length === 0 || plantItems.length === 0) {
      return {
        searchValue: searchItems.map(i => i.value).join(', '),
        plantValue: plantItems.map(i => i.value).join(', '),
        score: 0,
      };
    }

    // Find the best cross-match
    let bestScore = 0;
    let bestSearchItem = searchItems[0];
    let bestPlantItem = plantItems[0];

    for (const searchItem of searchItems) {
      for (const plantItem of plantItems) {
        const score = compareTwoStrings(searchItem.value, plantItem.value);
        if (score > bestScore) {
          bestScore = score;
          bestSearchItem = searchItem;
          bestPlantItem = plantItem;
        }
      }
    }

    return {
      searchValue: bestSearchItem.value,
      plantValue: bestPlantItem.value,
      score: bestScore,
    };
  };  /**
   * Calculate full name similarity
   */
  const calculateFullNameMatch = (searchName: string, plantName: string): ComponentMatchResult => {
    const score = compareTwoStrings(searchName, plantName);

    return {
      searchValue: searchName,
      plantValue: plantName,
      score,
    };
  };  /**
   * Calculate weighted total similarity score using consistent weights
   */
  const calculateWeightedScore = (
    componentResults: { genus: ComponentMatchResult; species: ComponentMatchResult; sortBrandName: ComponentMatchResult; fullName: ComponentMatchResult },
    weights: SimilarityWeights = DEFAULT_WEIGHTS
  ): { score: number; weights: SimilarityWeights; reweighted: boolean } => {
    // Always use the same weights - no reweighting based on cultivar presence
    const finalWeights = { ...weights };

    const weightedSum = 
      componentResults.genus.score * finalWeights.genus +
      componentResults.species.score * finalWeights.species +
      componentResults.sortBrandName.score * finalWeights.sortBrandName +
      componentResults.fullName.score * finalWeights.fullName;

    const totalWeight = Object.values(finalWeights).reduce((sum, weight) => sum + weight, 0);
    const finalScore = weightedSum / totalWeight;

    return {
      score: finalScore,
      weights: finalWeights,
      reweighted: false // Always false since we removed reweighting
    };
  };/**
   * Find best matches for a search query using plants_match RPC function
   */
  const findBestMatches = async (
    searchQuery: string,
    options: {
      limit?: number;
      minimumScore?: number;
      weights?: SimilarityWeights;
      includeStrictMatchesOnly?: boolean;
    } = {}
  ): Promise<{
    strictMatches: SimilarityResult[];
    suggestions: SimilarityResult[];
    hasStrictMatch: boolean;
  }> => {
    const {
      limit = 10,
      minimumScore = 0.3,
      weights = DEFAULT_WEIGHTS,
      includeStrictMatchesOnly = false,
    } = options;

    if (!searchQuery || searchQuery.length < 2) {
      return {
        strictMatches: [],
        suggestions: [],
        hasStrictMatch: false,
      };
    }

    try {
      const supabase = useSupabaseClient();
      
      // Use the plants_match RPC function (main entry point that handles strict + fuzzy)
      const { data: rpcResults, error } = await supabase.rpc('plants_match', {
        p_search_term: searchQuery,
      } as any);

      if (error) {
        console.error('Error calling plants_match RPC:', error);
        return {
          strictMatches: [],
          suggestions: [],
          hasStrictMatch: false,
        };
      }

      // Type assertion for the RPC results
      const rpcMatches = rpcResults as any[] | null;

      if (!rpcMatches || !Array.isArray(rpcMatches) || rpcMatches.length === 0) {
        return {
          strictMatches: [],
          suggestions: [],
          hasStrictMatch: false,
        };
      }      // Convert RPC results to SimilarityResult format
      const results: SimilarityResult[] = [];// Process each match
      for (const rpcMatch of rpcMatches) {        // Convert RPC result to Facit-like object for similarity calculation
        const plant: Facit = {
          id: rpcMatch.id,
          name: rpcMatch.name,
          sv_name: rpcMatch.sv_name,
          // Add minimal required fields for Facit interface
          created_at: '',
          is_recommended: null,
          is_original: null,
          is_synonym: null,
          synonym_to: null,
          synonym_to_id: null,
          has_synonyms: rpcMatch.has_synonyms,
          has_synonyms_id: rpcMatch.has_synonyms_id,
          taxonomy_type: null,
          plant_type: rpcMatch.plant_type || null,
          grupp: rpcMatch.grupp || null,
          serie: rpcMatch.serie || null,
          spread: null,
          height: null,
          rhs_id: null,
          sunlight: null,
          soil_type: null,
          full_height_time: null,
          moisture: null,
          ph: null,
          exposure: null,
          season_of_interest: null,
          colors: null,
          rhs_types: null,
          user_submitted: rpcMatch.user_submitted || null,
          created_by: rpcMatch.created_by || null,
          last_edited: null,
        };// Calculate client-side similarity score
        const searchComponents = parseStandablantName(searchQuery);
        const plantComponents = parseStandablantName(plant.name);
        const componentScores = calculateComponentSimilarity(searchComponents, plantComponents);
  // Calculate weighted score using consistent weights
        let scoreResult = calculateWeightedScore(componentScores, weights);
        
        let totalScore = scoreResult.score;
        let bestMatchName = plant.name;
        let bestComponentScores = componentScores;
        let bestMatchSource: 'main_name' | 'sv_name' | 'synonym' = 'main_name';        let usedWeights = scoreResult.weights;// Also check sv_name if it exists
        if (plant.sv_name) {
          const svComponents = parseStandablantName(plant.sv_name);
          const svComponentScores = calculateComponentSimilarity(searchComponents, svComponents);
          const svPlantHasCultivar = svComponentScores.sortBrandName.plantValue.length > 0;          const svScoreResult = calculateWeightedScore(svComponentScores, weights);
          
          if (svScoreResult.score > totalScore) {
            totalScore = svScoreResult.score;
            bestMatchName = plant.sv_name;
            bestComponentScores = svComponentScores;
            bestMatchSource = 'sv_name';            usedWeights = svScoreResult.weights;
          }
        }        // Check if matched synonym has better score
        if (rpcMatch.matched_synonym_name) {
          const synonymComponents = parseStandablantName(rpcMatch.matched_synonym_name);
          const synonymComponentScores = calculateComponentSimilarity(searchComponents, synonymComponents);
          const synonymScoreResult = calculateWeightedScore(synonymComponentScores, weights);
          
          if (synonymScoreResult.score > totalScore) {
            totalScore = synonymScoreResult.score;
            bestMatchName = rpcMatch.matched_synonym_name;
            bestComponentScores = synonymComponentScores;
            bestMatchSource = 'synonym';            usedWeights = synonymScoreResult.weights;
          }
        }        // Boost score based on SQL match_details (database confidence)
        if (rpcMatch.match_details && typeof rpcMatch.match_details === 'string') {
          // Small boost for SQL matches
          totalScore = Math.min(1.0, totalScore + 0.05);
        }

        // Determine if this is a strict match
        const isStrictMatch = totalScore >= 0.95 && bestComponentScores.sortBrandName.score >= 0.7;

        const matchDetails = JSON.stringify({
          searchQuery,
          bestMatchName,
          totalScore,
          isStrictMatch,
          componentScores: bestComponentScores,
          searchComponents,
          plantComponents: parseStandablantName(bestMatchName),
          usedSvName: bestMatchName === plant.sv_name,
          usedSynonym: bestMatchName === rpcMatch.matched_synonym_name,
          sqlMatchDetails: rpcMatch.match_details,
          matchedSynonymName: rpcMatch.matched_synonym_name,
          matchedSynonymId: rpcMatch.matched_synonym_id,
          reweighted: false,
          usedWeights: usedWeights
        });        results.push({
          id: plant.id,
          name: plant.name,
          sv_name: plant.sv_name,
          plant_type: plant.plant_type,
          grupp: plant.grupp,
          serie: plant.serie,
          totalScore,
          isStrictMatch,
          componentScores: {
            genus: bestComponentScores.genus,
            species: bestComponentScores.species,
            sortBrandName: bestComponentScores.sortBrandName,
            fullName: bestComponentScores.fullName,
          },
          bestMatchSource: bestMatchSource,
          matchDetails,
        });
      }      // Sort by total score and strict match status
      results.sort((a, b) => {
        // Strict matches first
        if (a.isStrictMatch && !b.isStrictMatch) return -1;
        if (b.isStrictMatch && !a.isStrictMatch) return 1;
        
        // Then by total score
        if (b.totalScore !== a.totalScore) return b.totalScore - a.totalScore;
        
        // Then by name length (shorter preferred)
        return a.name.length - b.name.length;
      });// Filter by minimum score
      const filteredResults = results.filter(result => result.totalScore >= minimumScore);
      
      // Separate strict matches from suggestions
      const strictMatches = filteredResults.filter(result => result.isStrictMatch);
      const suggestions = includeStrictMatchesOnly 
        ? [] 
        : filteredResults.filter(result => !result.isStrictMatch).slice(0, limit);

      // Log the matches
      logMatches(searchQuery, [...strictMatches, ...suggestions]);

      return {
        strictMatches,
        suggestions,
        hasStrictMatch: strictMatches.length > 0,
      };

    } catch (error) {
      console.error('Error in findBestMatches:', error);
      return {
        strictMatches: [],
        suggestions: [],
        hasStrictMatch: false,
      };
    }
  };


  /**
   * Convert SimilarityResult to PlantSearchResult format for compatibility
   */
  const convertToPlantSearchResult = (similarityResult: SimilarityResult): PlantSearchResult & { similarity_score: number; match_details: string } => {
    // Parse the match details to extract SQL information
    let parsedDetails;
    try {
      parsedDetails = JSON.parse(similarityResult.matchDetails);
    } catch {
      parsedDetails = {};
    }    return {
      id: similarityResult.id,
      name: similarityResult.name,
      sv_name: similarityResult.sv_name,
      plant_type: similarityResult.plant_type,
      grupp: similarityResult.grupp,
      serie: similarityResult.serie,
      rhs_types: null,
      is_synonym: null,
      synonym_to: null,
      synonym_to_id: null,
      spread: null,
      height: null,
      colors: null,
      last_edited: null,
      similarity_score: similarityResult.totalScore,
      match_details: similarityResult.matchDetails,
      // Add SQL-specific information for compatibility with existing code
      matched_synonym_name: parsedDetails.matchedSynonymName || null,
      matched_synonym_id: parsedDetails.matchedSynonymId || null,
    } as PlantSearchResult & { 
      similarity_score: number; 
      match_details: string;
      matched_synonym_name?: string | null;
      matched_synonym_id?: string | null;    };
  };  /**
   * Trigger showing additional matches (callable from console or programmatically)
   */
  const showMoreMatches = () => {
    console.log('Additional matches functionality has been simplified.');
  };  return {
    findBestMatches,
    convertToPlantSearchResult,
    parseStandablantName,
    logMatches,
    showMoreMatches,
    DEFAULT_WEIGHTS,
  };
};
