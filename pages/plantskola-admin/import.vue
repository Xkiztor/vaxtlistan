<script setup lang="ts">
// Advanced import page for nursery owners (plantskolor)
// Import from CSV, Excel, JSON, or other formats
// Sanitize data
// User choose how to map the column names to the database fields
// All the plant names are validated against the facit database
// The ones that are found are inserted as the correct facit_id into the totallager table
// The ones that are not found are added to a queue for manual review
// The manual review could find the plant names with fuzzy search and then show "Menade du X?" for the user to confirm.
// The manual review for the plants that did not get found in last step could use plantPicker to find the correct plant or add if it doesn't exist
// The user can then review and correct the mappings before final import

import Papa from 'papaparse';
import * as XLSX from 'xlsx';
import type { Totallager, Facit, PlantSearchResult } from '~/types/supabase-tables';
import type { SearchOptions } from '~/composables/useSearch';

const user = useSupabaseUser();
const supabase = useSupabaseClient();
const router = useRouter();
const { searchPlants } = useSearch();
const toast = useToast();

definePageMeta({
  layout: 'admin',
  middleware: 'plantskola-admin',
});

// Get current plantskola
const { data: plantskola } = (await useAsyncData('currentPlantskola', async () => {
  if (!user.value) return null;

  const { data, error } = await supabase
    .from('plantskolor')
    .select('*')
    .eq('user_id', user.value.id)
    .single();

  if (error) {
    console.error('Error fetching plantskola:', error);
    return null;
  }
  return data;
})) as { data: Ref<any> };

// Import workflow states
const currentStep = ref(1);
const totalSteps = 5;
const stepLoading = ref(false);
const completedSteps = ref(new Set([1])); // Track which steps have been completed

// File handling
const selectedFile = ref<File | null>(null);
const fileInput = ref<HTMLInputElement>();
const dragActive = ref(false);

// Parsed data
const rawData = ref<any[]>([]);
const headers = ref<string[]>([]);
const previewData = ref<any[]>([]);

// Column mapping
const columnMapping = ref<Record<string, string>>({});
const requiredFields = [
  { key: 'name', label: 'Växtnamn', required: true },
  { key: 'stock', label: 'Lager', required: false },
  { key: 'price', label: 'Pris', required: false },
  { key: 'pot', label: 'Kruka', required: false },
  { key: 'height', label: 'Höjd', required: false },
  { key: 'comment', label: 'Kommentar', required: false },
];

// Plant validation
const validatedPlants = ref<
  {
    original: any;
    facitMatch: Facit | null;
    suggestions: PlantSearchResult[];
    selectedFacitId: number | null;
    status: 'found' | 'notFound' | 'manual' | 'skip';
  }[]
>([]);

// Validation progress tracking
const validationProgress = ref({
  currentPlant: '',
  currentBatch: 0,
  totalBatches: 0,
  plantsProcessed: 0,
  totalPlants: 0,
});

// Import progress
const importing = ref(false);
const importProgress = ref(0);
const importResults = ref<{
  success: number;
  failed: number;
  skipped: number;
  errors: string[];
}>({
  success: 0,
  failed: 0,
  skipped: 0,
  errors: [],
});

// File upload handlers
const handleFileSelect = (event: Event) => {
  const target = event.target as HTMLInputElement;
  if (target.files && target.files[0]) {
    selectedFile.value = target.files[0];
    parseFile(target.files[0]);
  }
};

const handleDrop = (event: DragEvent) => {
  event.preventDefault();
  dragActive.value = false;

  if (event.dataTransfer?.files && event.dataTransfer.files[0]) {
    selectedFile.value = event.dataTransfer.files[0];
    parseFile(event.dataTransfer.files[0]);
  }
};

const handleDragOver = (event: DragEvent) => {
  event.preventDefault();
  dragActive.value = true;
};

const handleDragLeave = () => {
  dragActive.value = false;
};

// File parsing
const parseFile = async (file: File) => {
  stepLoading.value = true;
  try {
    const fileType = file.type;
    const fileName = file.name.toLowerCase();

    if (fileType === 'text/csv' || fileName.endsWith('.csv')) {
      await parseCSV(file);
    } else if (
      fileType === 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' ||
      fileType === 'application/vnd.ms-excel' ||
      fileName.endsWith('.xlsx') ||
      fileName.endsWith('.xls')
    ) {
      await parseExcel(file);
    } else if (fileType === 'application/json' || fileName.endsWith('.json')) {
      await parseJSON(file);
    } else {
      throw new Error('Filtyp stöds inte. Välj CSV, Excel eller JSON-fil.');
    }

    // Move to next step after successful parsing
    if (rawData.value.length > 0) {
      setupColumnMapping();

      // Add a small delay for better UX
      await new Promise((resolve) => setTimeout(resolve, 500));

      completedSteps.value.add(2);
      currentStep.value = 2;
    }
  } catch (error: any) {
    console.error('Error parsing file:', error);
    toast.add({
      title: 'Fel vid filparsning',
      description: error.message,
      color: 'error',
    });
  } finally {
    stepLoading.value = false;
  }
};

const parseCSV = async (file: File): Promise<void> => {
  return new Promise((resolve, reject) => {
    Papa.parse(file, {
      header: true,
      skipEmptyLines: true,
      encoding: 'UTF-8',
      complete: (results) => {
        if (results.errors.length > 0) {
          console.warn('CSV parsing warnings:', results.errors);
        }

        rawData.value = results.data as any[];
        headers.value = results.meta.fields || [];
        previewData.value = rawData.value.slice(0, 5);
        resolve();
      },
      error: (error) => {
        reject(new Error(`Fel vid CSV-parsning: ${error.message}`));
      },
    });
  });
};

const parseExcel = async (file: File): Promise<void> => {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();

    reader.onload = (e) => {
      try {
        const data = new Uint8Array(e.target?.result as ArrayBuffer);
        const workbook = XLSX.read(data, { type: 'array' });

        // Use first sheet
        const sheetName = workbook.SheetNames[0];
        const worksheet = workbook.Sheets[sheetName];

        // Convert to JSON with header row
        const jsonData = XLSX.utils.sheet_to_json(worksheet, {
          header: 1,
          defval: '',
        }) as any[][];

        if (jsonData.length < 2) {
          reject(new Error('Excel-filen måste ha minst en rubrikrad och en datarad.'));
          return;
        }

        // Extract headers and data
        headers.value = jsonData[0] as string[];
        const dataRows = jsonData.slice(1);

        // Convert rows to objects
        rawData.value = dataRows.map((row) => {
          const obj: any = {};
          headers.value.forEach((header, index) => {
            obj[header] = row[index] || '';
          });
          return obj;
        });

        previewData.value = rawData.value.slice(0, 5);
        resolve();
      } catch (error: any) {
        reject(new Error(`Fel vid Excel-parsning: ${error.message}`));
      }
    };

    reader.onerror = () => {
      reject(new Error('Kunde inte läsa Excel-filen.'));
    };

    reader.readAsArrayBuffer(file);
  });
};

const parseJSON = async (file: File): Promise<void> => {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();

    reader.onload = (e) => {
      try {
        const jsonData = JSON.parse(e.target?.result as string);

        if (!Array.isArray(jsonData)) {
          reject(new Error('JSON-filen måste innehålla en array av objekt.'));
          return;
        }

        if (jsonData.length === 0) {
          reject(new Error('JSON-filen är tom.'));
          return;
        }

        rawData.value = jsonData;
        headers.value = Object.keys(jsonData[0] || {});
        previewData.value = rawData.value.slice(0, 5);
        resolve();
      } catch (error: any) {
        reject(new Error(`Fel vid JSON-parsning: ${error.message}`));
      }
    };

    reader.onerror = () => {
      reject(new Error('Kunde inte läsa JSON-filen.'));
    };

    reader.readAsText(file, 'UTF-8');
  });
};

// Column mapping setup
const setupColumnMapping = () => {
  // Auto-detect common column names
  const mapping: Record<string, string> = {};

  headers.value.forEach((header) => {
    const lowerHeader = header.toLowerCase();

    if (
      (lowerHeader.includes('name') && !lowerHeader.includes('sv')) ||
      (lowerHeader.includes('namn') && !lowerHeader.includes('sv')) ||
      lowerHeader.includes('art') ||
      lowerHeader.includes('vetenskapligt') ||
      lowerHeader.includes('växt')
    ) {
      mapping['name'] = header;
    } else if (
      lowerHeader.includes('stock') ||
      lowerHeader.includes('antal') ||
      lowerHeader.includes('lager')
    ) {
      mapping['stock'] = header;
    } else if (
      lowerHeader.includes('pot') ||
      lowerHeader.includes('kruka') ||
      lowerHeader.includes('kruk') ||
      lowerHeader.includes('ruka') ||
      lowerHeader.includes('container')
    ) {
      mapping['pot'] = header;
    } else if (
      lowerHeader.includes('price') ||
      lowerHeader.includes('pris') ||
      (lowerHeader.includes('kr') && !lowerHeader.includes('kruk')) ||
      lowerHeader.includes('kostnad')
    ) {
      mapping['price'] = header;
    } else if (
      lowerHeader.includes('height') ||
      lowerHeader.includes('höjd') ||
      lowerHeader.includes('storlek')
    ) {
      mapping['height'] = header;
    } else if (
      lowerHeader.includes('comment') ||
      lowerHeader.includes('kommentar') ||
      lowerHeader.includes('anteckning') ||
      lowerHeader.includes('info') ||
      lowerHeader.includes('notering') ||
      lowerHeader.includes('beskrivning')
    ) {
      mapping['comment'] = header;
    }
  });
  columnMapping.value = mapping;
};

// Data sanitization functions
const sanitizePlantName = (name: string): string => {
  if (!name) return '';

  return (
    name
      .toString()
      .trim()
      // Remove multiple spaces and replace with single space
      .replace(/\s+/g, ' ')
      // Remove leading/trailing quotes and brackets
      .replace(/^["'\[\(]+|["'\]\)]+$/g, '')
      // Normalize common punctuation
      .replace(/[""`´]/g, "'") // Replace various quote types with standard apostrophe
      .replace(/[\u2018\u2019]/g, "'") // Replace smart quotes
      .replace(/[\u201C\u201D]/g, '"') // Replace smart double quotes
      // Remove unnecessary punctuation but keep apostrophes and hyphens
      .replace(/[^\w\s''\-×.()]/g, '')
      // Normalize case - capitalize first letter of each word
      .split(' ')
      .map((word) => {
        if (word.length === 0) return word;
        // Keep cultivar names in single quotes as they are
        if (word.startsWith("'") && word.endsWith("'")) return word;
        // Capitalize first letter, lowercase the rest
        return word.charAt(0).toUpperCase() + word.slice(1).toLowerCase();
      })
      .join(' ')
      // Clean up any remaining double spaces
      .replace(/\s+/g, ' ')
      .trim()
  );
};

const sanitizeNumericValue = (value: any): number => {
  if (!value && value !== 0) return 0;

  const stringValue = value
    .toString()
    .trim()
    // Remove common currency symbols and units
    .replace(/[kr\$€£¥₹₽]/gi, '')
    .replace(/\s*(kr|sek|eur|usd|cm|mm|m)\s*$/gi, '')
    // Remove thousands separators
    .replace(/[\s,]/g, '')
    // Handle decimal separators (both . and ,)
    .replace(',', '.');

  const parsed = parseFloat(stringValue);
  return isNaN(parsed) ? 0 : Math.max(0, parsed);
};

const sanitizeTextValue = (value: any): string => {
  if (!value) return '';

  return (
    value
      .toString()
      .trim()
      // Remove excessive whitespace
      .replace(/\s+/g, ' ')
      // Remove potentially harmful characters
      .replace(/[<>]/g, '')
      .trim()
  );
};

// Plant validation with improved error handling and performance
const validatePlants = async () => {
  if (!columnMapping.value.name) {
    toast.add({
      title: 'Saknad kolumnmappning',
      description: 'Du måste matcha växtnamn-kolumnen för att fortsätta.',
      color: 'error',
    });
    return;
  }

  stepLoading.value = true;
  currentStep.value = 3;
  validatedPlants.value = [];

  // Initialize progress tracking
  validationProgress.value = {
    currentPlant: '',
    currentBatch: 0,
    totalBatches: 0,
    plantsProcessed: 0,
    totalPlants: rawData.value.length,
  };

  try {
    console.log(`Starting validation of ${rawData.value.length} plants...`);
    const batchSize = 10; // Process in smaller batches for better UX
    const totalBatches = Math.ceil(rawData.value.length / batchSize);
    validationProgress.value.totalBatches = totalBatches;

    for (let batchIndex = 0; batchIndex < totalBatches; batchIndex++) {
      const startIndex = batchIndex * batchSize;
      const endIndex = Math.min(startIndex + batchSize, rawData.value.length);
      const batch = rawData.value.slice(startIndex, endIndex);

      validationProgress.value.currentBatch = batchIndex + 1;
      console.log(
        `Processing batch ${batchIndex + 1}/${totalBatches} (rows ${startIndex + 1}-${endIndex})`
      );

      // Process batch with individual error handling
      for (const [localIndex, row] of batch.entries()) {
        const globalIndex = startIndex + localIndex;
        const rawPlantName = row[columnMapping.value.name]?.toString().trim() || '';
        validationProgress.value.currentPlant = rawPlantName;
        validationProgress.value.plantsProcessed = globalIndex + 1;

        try {
          await validateSinglePlant(row, globalIndex);
        } catch (error: any) {
          console.error(`Error validating plant at row ${globalIndex + 1}:`, error);

          // Add as skip on error to prevent blocking the whole process
          validatedPlants.value.push({
            original: row,
            facitMatch: null,
            suggestions: [],
            selectedFacitId: null,
            status: 'skip',
          });
        }
      }

      // Small delay between batches to prevent blocking the UI
      if (batchIndex < totalBatches - 1) {
        await new Promise((resolve) => setTimeout(resolve, 50));
      }
    }

    console.log(`Validation completed. ${validatedPlants.value.length} plants processed.`);

    completedSteps.value.add(3);
    completedSteps.value.add(4);
    currentStep.value = 4;

    // Show summary
    const found = validatedPlants.value.filter((p) => p.status === 'found').length;
    const notFound = validatedPlants.value.filter((p) => p.status === 'notFound').length;
    const skipped = validatedPlants.value.filter((p) => p.status === 'skip').length;

    toast.add({
      title: 'Validering klar',
      description: `${found} hittades, ${notFound} behöver granskas, ${skipped} hoppades över`,
      color: 'primary',
    });
  } catch (error: any) {
    console.error('Critical error during plant validation:', error);
    toast.add({
      title: 'Fel vid validering',
      description: `Ett kritiskt fel uppstod: ${error.message}`,
      color: 'error',
    });

    // Reset to previous step if critical error
    currentStep.value = 2;
  } finally {
    stepLoading.value = false;
    // Clear progress tracking
    validationProgress.value.currentPlant = '';
  }
};

// Validate a single plant with timeout and error recovery
const validateSinglePlant = async (row: any, index: number) => {
  const rawPlantName = row[columnMapping.value.name]?.toString().trim();
  const sanitizedPlantName = sanitizePlantName(rawPlantName);

  console.log(`Validating plant ${index + 1}: "${rawPlantName}" -> "${sanitizedPlantName}"`);

  if (!sanitizedPlantName || sanitizedPlantName.length < 2) {
    validatedPlants.value.push({
      original: row,
      facitMatch: null,
      suggestions: [],
      selectedFacitId: null,
      status: 'skip',
    });
    return;
  }

  // Add timeout to prevent hanging on slow queries
  const timeoutPromise = new Promise((_, reject) => {
    setTimeout(() => reject(new Error('Search timeout')), 8000); // Reduced to 8 seconds
  });

  try {
    // Search for exact match first with timeout
    const exactMatch = (await Promise.race([
      searchExactPlant(sanitizedPlantName),
      timeoutPromise,
    ])) as Facit | null;

    if (exactMatch) {
      console.log(`✓ Exact match found for "${sanitizedPlantName}": ${exactMatch.name}`);
      validatedPlants.value.push({
        original: row,
        facitMatch: exactMatch,
        suggestions: [],
        selectedFacitId: exactMatch.id,
        status: 'found',
      });
      return;
    }

    // Only search for suggestions if plant name is substantial enough
    if (sanitizedPlantName.length >= 4) {
      console.log(`No exact match for "${sanitizedPlantName}", searching suggestions...`);

      const suggestions = (await Promise.race([
        searchSimilarPlants(sanitizedPlantName),
        timeoutPromise,
      ])) as PlantSearchResult[];

      console.log(`Found ${suggestions.length} suggestions for "${sanitizedPlantName}"`);

      validatedPlants.value.push({
        original: row,
        facitMatch: null,
        suggestions: suggestions.slice(0, 5), // Limit suggestions to prevent UI overload
        selectedFacitId: null,
        status: 'notFound',
      });
    } else {
      // For very short names, skip suggestions to avoid too many false positives
      console.log(`Skipping suggestions for short name "${sanitizedPlantName}"`);
      validatedPlants.value.push({
        original: row,
        facitMatch: null,
        suggestions: [],
        selectedFacitId: null,
        status: 'notFound',
      });
    }
  } catch (error: any) {
    console.warn(`Failed to validate plant "${sanitizedPlantName}":`, error.message);

    // On timeout or error, mark as not found with no suggestions
    validatedPlants.value.push({
      original: row,
      facitMatch: null,
      suggestions: [],
      selectedFacitId: null,
      status: 'notFound',
    });
  }
};

const searchExactPlant = async (plantName: string): Promise<Facit | null> => {
  try {
    console.log(`Searching exact match for: "${plantName}"`);

    // First try exact match (case-insensitive)
    const { data: exactData, error: exactError } = await supabase
      .from('facit')
      .select('id, name, sv_name')
      .ilike('name', plantName)
      .limit(1)
      .returns<Facit[]>();

    if (!exactError && exactData && exactData.length > 0) {
      console.log(`✓ Found exact match: "${exactData[0].name}" for input: "${plantName}"`);
      return exactData[0];
    }

    // Try normalized variations for common formatting differences
    const quickVariations = [
      // Remove quotes and parentheses
      plantName.replace(/['"()]/g, '').trim(),
      // Normalize spacing
      plantName.replace(/\s+/g, ' ').trim(),
      // Remove common punctuation that might interfere
      plantName.replace(/[.,;:]/g, '').trim(),
      // Handle common abbreviations (cv., var., subsp., etc.)
      plantName
        .replace(/\b(cv|var|subsp|ssp|f|forma)\b\.?/gi, '')
        .replace(/\s+/g, ' ')
        .trim(),
    ].filter((v) => v !== plantName && v.length >= 3);

    for (const variation of quickVariations) {
      console.log(`Trying variation: "${variation}"`);
      const { data: varData, error: varError } = await supabase
        .from('facit')
        .select('id, name, sv_name')
        .ilike('name', variation)
        .limit(1)
        .returns<Facit[]>();

      if (!varError && varData && varData.length > 0) {
        console.log(`✓ Found variation match: "${varData[0].name}" for variation: "${variation}"`);
        return varData[0];
      }
    }

    // Try prefix match for genus + species (but only if it's a reasonable length)
    if (plantName.length >= 6 && plantName.includes(' ')) {
      console.log(`Trying prefix match for: "${plantName}"`);
      const { data: prefixData, error: prefixError } = await supabase
        .from('facit')
        .select('id, name, sv_name')
        .ilike('name', `${plantName}%`)
        .limit(1)
        .returns<Facit[]>();

      if (!prefixError && prefixData && prefixData.length > 0) {
        // Only return prefix match if it's very close to the original
        const foundName = prefixData[0].name.toLowerCase();
        const searchName = plantName.toLowerCase();

        // Check if the found name starts with our search and is reasonably close
        if (foundName.startsWith(searchName) && foundName.length - searchName.length <= 15) {
          // Allow some extra cultivar/variety info
          console.log(`✓ Found prefix match: "${prefixData[0].name}" for input: "${plantName}"`);
          return prefixData[0];
        }
      }
    }

    console.log(`No exact match found for: "${plantName}"`);
    return null;
  } catch (error) {
    console.error('Error in searchExactPlant:', error);
    return null;
  }
};

const searchSimilarPlants = async (plantName: string): Promise<PlantSearchResult[]> => {
  try {
    console.log(`Searching similar plants for: "${plantName}"`);

    // Use lower threshold for SQL and do more filtering in JavaScript for better performance
    const sqlThreshold = plantName.length < 8 ? 0.3 : 0.25;

    // Try the optimized similarity RPC function first
    let { data, error } = (await (supabase as any).rpc('search_plants_similarity_fast', {
      search_term: plantName,
      similarity_threshold: sqlThreshold,
      result_limit: 8, // Reduced limit for better performance
      result_offset: 0,
    })) as { data: PlantSearchResult[] | null; error: any };

    // If the advanced function fails, try the basic similarity function
    if (error) {
      console.log('Advanced similarity search failed, trying basic version...', error);

      const basicResult = (await (supabase as any).rpc('search_plants_similarity_basic', {
        search_term: plantName,
        result_limit: 8,
        result_offset: 0,
      })) as { data: PlantSearchResult[] | null; error: any };

      if (basicResult.error) {
        console.warn('Basic similarity search also failed:', basicResult.error);
        return await fallbackSimilaritySearch(plantName);
      }

      data = basicResult.data;
      error = basicResult.error;
    }

    let results = (data || []) as PlantSearchResult[];
    console.log(`Found ${results.length} similar plants using RPC similarity search`);

    // Apply fast client-side filtering with smart logic
    const filteredResults = applyFastFiltering(results, plantName);
    console.log(`After fast filtering: ${filteredResults.length} high-quality suggestions`);
    return filteredResults;
  } catch (error) {
    console.error('Error in searchSimilarPlants:', error);
    // Fallback to basic search on error
    return await fallbackSimilaritySearch(plantName);
  }
};

// Simple fallback similarity calculation for better performance
const calculateFallbackSimilarity = (str1: string, str2: string): number => {
  if (!str1 || !str2) return 0;
  if (str1 === str2) return 1.0;

  // Prefix match bonus
  if (str2.startsWith(str1) || str1.startsWith(str2)) return 0.9;

  // Substring match bonus
  if (str2.includes(str1) || str1.includes(str2)) return 0.7;

  // Simple word overlap calculation
  const words1 = str1.split(/\s+/).filter((w) => w.length > 2);
  const words2 = str2.split(/\s+/).filter((w) => w.length > 2);

  if (words1.length === 0 || words2.length === 0) return 0;

  let commonWords = 0;
  for (const word1 of words1) {
    if (words2.some((word2) => word2.includes(word1) || word1.includes(word2))) {
      commonWords++;
    }
  }

  return commonWords / Math.max(words1.length, words2.length);
};

// Fallback similarity search if RPC is not available
const fallbackSimilaritySearch = async (plantName: string): Promise<PlantSearchResult[]> => {
  try {
    console.log(`Using fallback similarity search for: "${plantName}"`);

    // Search only scientific names directly (avoid Swedish names)
    const { data, error } = await supabase
      .from('facit')
      .select('id, name, sv_name')
      .ilike('name', `%${plantName}%`)
      .limit(6) // Reduced limit for better performance
      .returns<PlantSearchResult[]>();

    if (error) {
      console.warn('Fallback similarity search error:', error);
      return [];
    }

    const results = data || [];
    console.log(`Found ${results.length} similar plants using fallback substring search`);

    // Calculate similarity scores manually for fallback results
    const scoredResults = results.map((result) => ({
      ...result,
      similarity_score: calculateFallbackSimilarity(
        plantName.toLowerCase(),
        result.name.toLowerCase()
      ),
    }));

    // Apply the same fast filtering
    const filteredResults = applyFastFiltering(scoredResults, plantName);

    console.log(`After fast filtering: ${filteredResults.length} relevant results`);
    return filteredResults;
  } catch (error) {
    console.error('Error in fallback similarity search:', error);
    return [];
  }
};

// Fast filtering function optimized for performance on large datasets
const applyFastFiltering = (
  results: PlantSearchResult[],
  searchTerm: string
): PlantSearchResult[] => {
  if (!results || results.length === 0) {
    console.log('No results to filter');
    return [];
  }

  // Simple threshold based on search term length
  const minThreshold = searchTerm.length < 8 ? 0.4 : 0.3;
  const excellentThreshold = 0.85;

  // Filter and sort results efficiently
  const filteredResults = results
    .filter((result) => {
      const score = (result as any).similarity_score || 0;
      return score >= minThreshold;
    })
    .sort((a, b) => {
      const scoreA = (a as any).similarity_score || 0;
      const scoreB = (b as any).similarity_score || 0;
      if (scoreB !== scoreA) return scoreB - scoreA;
      // Secondary sort by name length for same scores
      return a.name.length - b.name.length;
    });

  if (filteredResults.length === 0) {
    console.log(`No results above minimum threshold of ${minThreshold}`);
    return [];
  }

  const topScore = (filteredResults[0] as any).similarity_score || 0;
  console.log(`Best similarity score: ${topScore} for "${filteredResults[0].name}"`);

  // If we have an excellent match, return only that one
  if (topScore >= excellentThreshold) {
    console.log(`Excellent match found (${topScore}), returning only the best result`);
    return [filteredResults[0]];
  }

  // If the top result is significantly better, limit suggestions
  if (filteredResults.length > 1) {
    const secondScore = (filteredResults[1] as any).similarity_score || 0;
    const gap = topScore - secondScore;

    if (gap >= 0.15 && topScore >= 0.7) {
      console.log(`Significant gap found (${gap}), returning top 2 results only`);
      return filteredResults.slice(0, 2);
    }
  }

  // Return maximum 4 suggestions for good UX
  const maxSuggestions = topScore >= 0.8 ? 2 : 4;
  return filteredResults.slice(0, maxSuggestions);
};

// Helper function to check if two plant names share meaningful words
const hasSharedMeaningfulWords = (searchTerm: string, plantName: string): boolean => {
  const searchWords = searchTerm
    .toLowerCase()
    .split(/\s+/)
    .filter((word) => word.length >= 3); // Only consider words of 3+ characters

  const plantWords = plantName
    .toLowerCase()
    .split(/\s+/)
    .filter((word) => word.length >= 3);

  if (searchWords.length === 0 || plantWords.length === 0) return false;

  // Check if at least one meaningful word is shared (genus, species, etc.)
  const sharedWords = searchWords.filter((searchWord) =>
    plantWords.some(
      (plantWord) =>
        plantWord.includes(searchWord) ||
        searchWord.includes(plantWord) ||
        calculateLevenshteinDistance(searchWord, plantWord) <=
          Math.max(1, Math.floor(searchWord.length * 0.2))
    )
  );

  return sharedWords.length > 0;
};

// Simple Levenshtein distance for fuzzy word matching
const calculateLevenshteinDistance = (str1: string, str2: string): number => {
  const matrix = Array(str2.length + 1)
    .fill(null)
    .map(() => Array(str1.length + 1).fill(null));

  for (let i = 0; i <= str1.length; i++) matrix[0][i] = i;
  for (let j = 0; j <= str2.length; j++) matrix[j][0] = j;

  for (let j = 1; j <= str2.length; j++) {
    for (let i = 1; i <= str1.length; i++) {
      const indicator = str1[i - 1] === str2[j - 1] ? 0 : 1;
      matrix[j][i] = Math.min(
        matrix[j][i - 1] + 1, // deletion
        matrix[j - 1][i] + 1, // insertion
        matrix[j - 1][i - 1] + indicator // substitution
      );
    }
  }

  return matrix[str2.length][str1.length];
};

// Advanced similarity calculation for fallback search
const calculateAdvancedSimilarity = (str1: string, str2: string): number => {
  if (!str1 || !str2) return 0;
  if (str1 === str2) return 1.0;

  // Prefix match bonus
  if (str2.startsWith(str1) || str1.startsWith(str2)) return 0.9;

  // Substring match bonus
  if (str2.includes(str1) || str1.includes(str2)) return 0.7;

  // Word-based similarity (for scientific names)
  const wordSimilarity = calculateWordSimilarity(str1, str2);

  // Character-based similarity (for typos)
  const charSimilarity = calculateCharacterSimilarity(str1, str2);

  // Return the highest similarity score
  return Math.max(wordSimilarity, charSimilarity);
};

// Calculate similarity based on shared words (good for scientific names)
const calculateWordSimilarity = (str1: string, str2: string): number => {
  const words1 = str1.split(/\s+/).filter((w) => w.length > 1);
  const words2 = str2.split(/\s+/).filter((w) => w.length > 1);

  if (words1.length === 0 || words2.length === 0) return 0;

  let matchedWords = 0;
  let partialMatches = 0;

  for (const word1 of words1) {
    for (const word2 of words2) {
      if (word1 === word2) {
        matchedWords += 1;
      } else if (word1.includes(word2) || word2.includes(word1)) {
        partialMatches += 0.5;
      } else if (
        calculateLevenshteinDistance(word1, word2) <= Math.max(1, Math.floor(word1.length * 0.2))
      ) {
        partialMatches += 0.7; // Fuzzy word match
      }
    }
  }

  const totalMatches = matchedWords + partialMatches;
  return totalMatches / Math.max(words1.length, words2.length);
};

// Calculate character-based similarity using normalized Levenshtein distance
const calculateCharacterSimilarity = (str1: string, str2: string): number => {
  const maxLength = Math.max(str1.length, str2.length);
  if (maxLength === 0) return 1.0;

  const distance = calculateLevenshteinDistance(str1, str2);
  return 1 - distance / maxLength;
};

// Manual plant selection
const plantPickerModal = ref(false);
const selectedRowForPicker = ref<number | null>(null);

const openPlantPicker = (rowIndex: number) => {
  selectedRowForPicker.value = rowIndex;
  plantPickerModal.value = true;
};

const onPlantSelected = async (plantId: number) => {
  if (selectedRowForPicker.value !== null) {
    selectPlantForRow(selectedRowForPicker.value, plantId);

    // Update the selected plant details cache immediately
    try {
      const { data, error } = await supabase
        .from('facit')
        .select('id, name, sv_name')
        .eq('id', plantId)
        .single();

      if (!error && data) {
        selectedPlantDetails.value.set(selectedRowForPicker.value, data);
      }
    } catch (error) {
      console.warn('Failed to update selected plant details:', error);
    }
  }

  plantPickerModal.value = false;
  selectedRowForPicker.value = null;
};

const selectPlantForRow = (rowIndex: number, facitId: number) => {
  if (validatedPlants.value[rowIndex]) {
    validatedPlants.value[rowIndex].selectedFacitId = facitId;
    validatedPlants.value[rowIndex].status = 'manual';
  }
};

const skipPlantRow = (rowIndex: number) => {
  if (validatedPlants.value[rowIndex]) {
    validatedPlants.value[rowIndex].status = 'skip';
    validatedPlants.value[rowIndex].selectedFacitId = null;
    validatedPlants.value[rowIndex].facitMatch = null;
  }
};

// Revert plant to not found status so user can select again
const revertPlantRow = (rowIndex: number) => {
  if (validatedPlants.value[rowIndex]) {
    const plant = validatedPlants.value[rowIndex];
    const wasManualSelection = plant.status === 'manual';

    plant.status = 'notFound';
    plant.selectedFacitId = null;

    // Clear from selected plant details cache
    selectedPlantDetails.value.delete(rowIndex);

    // If this was a manual selection, clear the facitMatch
    // If it was an automatic find, we want to keep showing it as a suggestion
    if (wasManualSelection) {
      // Don't clear facitMatch as it might be useful as a suggestion
    }
  }
};

// Get selected plant details for display
const getSelectedPlantDetails = async (plant: any) => {
  if (!plant.selectedFacitId) return null;

  try {
    const { data, error } = await supabase
      .from('facit')
      .select('id, name, sv_name')
      .eq('id', plant.selectedFacitId)
      .single();

    if (error) {
      console.warn('Error fetching selected plant details:', error);
      return null;
    }

    return data;
  } catch (error) {
    console.error('Error getting selected plant details:', error);
    return null;
  }
};

// Reactive computed for plant details (we'll use this in template)
const selectedPlantDetails = ref<Map<number, any>>(new Map());

// Update selected plant details when plants change
watch(
  validatedPlants,
  async (newPlants) => {
    const newDetails = new Map();

    for (const [index, plant] of newPlants.entries()) {
      if (plant.status === 'manual' && plant.selectedFacitId) {
        const details = await getSelectedPlantDetails(plant);
        if (details) {
          newDetails.set(index, details);
        }
      }
    }

    selectedPlantDetails.value = newDetails;
  },
  { deep: true }
);

// Final import
const performImport = async () => {
  // Prevent double-clicking and multiple simultaneous imports
  if (importing.value || !plantskola.value) {
    if (importing.value) {
      console.warn('Import already in progress, ignoring click');
    } else {
      console.error('Plantskola not found');
    }
    return;
  }

  // Start import process
  importing.value = true;
  importProgress.value = 0;
  importResults.value = {
    success: 0,
    failed: 0,
    skipped: 0,
    errors: [],
  };

  try {
    console.log('Starting import process...');

    const plantsToImport = validatedPlants.value.filter(
      (plant) => plant.status !== 'skip' && plant.selectedFacitId
    );

    console.log(`Importing ${plantsToImport.length} plants...`);

    for (const [index, plant] of plantsToImport.entries()) {
      try {
        const lagerData: Partial<Totallager> = {
          facit_id: plant.selectedFacitId!,
          plantskola_id: plantskola.value.id,
          name_by_plantskola: sanitizePlantName(plant.original[columnMapping.value.name] || ''),
          comment_by_plantskola: columnMapping.value.comment
            ? sanitizeTextValue(plant.original[columnMapping.value.comment] || '')
            : '',
          pot: columnMapping.value.pot
            ? sanitizeTextValue(plant.original[columnMapping.value.pot] || '')
            : '',
          height: columnMapping.value.height
            ? sanitizeTextValue(plant.original[columnMapping.value.height] || '')
            : '',
          price: columnMapping.value.price
            ? sanitizeNumericValue(plant.original[columnMapping.value.price])
            : 0,
          stock: sanitizeNumericValue(plant.original[columnMapping.value.stock]),
          hidden: false,
        };

        const { error } = await supabase.from('totallager').insert(lagerData as any);

        if (error) throw error;

        importResults.value.success++;
        console.log(
          `Successfully imported plant ${index + 1}/${plantsToImport.length}: ${
            lagerData.name_by_plantskola
          }`
        );
      } catch (error: any) {
        console.error(`Error importing plant ${index + 1}:`, error);
        importResults.value.failed++;
        importResults.value.errors.push(`Rad ${index + 1}: ${error.message}`);
      }

      // Update progress
      importProgress.value = ((index + 1) / plantsToImport.length) * 100;

      // Small delay to prevent overwhelming the database
      if (index < plantsToImport.length - 1) {
        await new Promise((resolve) => setTimeout(resolve, 50));
      }
    }

    // Calculate skipped plants
    importResults.value.skipped = validatedPlants.value.filter(
      (plant) => plant.status === 'skip'
    ).length;

    // Move to results step
    completedSteps.value.add(5);
    currentStep.value = 5;

    console.log('Import completed:', importResults.value);

    // Show success notification
    if (importResults.value.success > 0) {
      toast.add({
        title: 'Import slutförd',
        description: `${importResults.value.success} växter importerades.`,
        color: 'success',
      });
    }

    if (importResults.value.failed > 0) {
      toast.add({
        title: 'Vissa fel uppstod',
        description: `${importResults.value.failed} växter kunde inte importeras.`,
        color: 'warning',
      });
    }
  } catch (error: any) {
    console.error('Critical error during import:', error);
    toast.add({
      title: 'Kritiskt fel vid import',
      description: `Ett oväntat fel uppstod: ${error.message}`,
      color: 'error',
    });
  } finally {
    // Always reset importing state
    importing.value = false;
  }
};

// Navigation
const goToStep = async (step: number) => {
  // Allow navigation to completed steps or the next step
  if (completedSteps.value.has(step) || step <= currentStep.value) {
    if (step !== currentStep.value) {
      stepLoading.value = true;

      // Add a small delay for better UX
      await new Promise((resolve) => setTimeout(resolve, 300));

      currentStep.value = step;
      stepLoading.value = false;
    }
  }
};

const resetImport = () => {
  currentStep.value = 1;
  stepLoading.value = false;
  completedSteps.value = new Set([1]); // Reset to only step 1 completed
  selectedFile.value = null;
  rawData.value = [];
  headers.value = [];
  previewData.value = [];
  columnMapping.value = {};
  validatedPlants.value = [];
  importResults.value = {
    success: 0,
    failed: 0,
    skipped: 0,
    errors: [],
  };

  if (fileInput.value) {
    fileInput.value.value = '';
  }
};

// Computed properties
const canProceedToMapping = computed(() => {
  return rawData.value.length > 0 && headers.value.length > 0;
});

const canProceedToValidation = computed(() => {
  const requiredMapped = requiredFields
    .filter((field) => field.required)
    .every((field) => columnMapping.value[field.key]);
  return requiredMapped;
});

const validationSummary = computed(() => {
  const found = validatedPlants.value.filter((p) => p.status === 'found').length;
  const manual = validatedPlants.value.filter((p) => p.status === 'manual').length;
  const notFound = validatedPlants.value.filter((p) => p.status === 'notFound').length;
  const skip = validatedPlants.value.filter((p) => p.status === 'skip').length;

  return { found, manual, notFound, skip, total: validatedPlants.value.length };
});

const canProceedToImport = computed(() => {
  return validationSummary.value.found + validationSummary.value.manual > 0;
});

// Template download
const downloadTemplate = () => {
  const csvContent = [
    'Växtnamn,Lagerantal,Pris,Krukstorlek,Höjd,Kommentar',
    'Acer palmatum,15,299,C3,40-60 cm,Röda höstfärger',
    'Rosa rugosa,8,199,C2,30-40 cm,Tålig rynkros',
    'Betula pendula,5,450,C5,80-100 cm,Vårtbjörk',
  ].join('\n');

  const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
  const link = document.createElement('a');
  const url = URL.createObjectURL(blob);

  link.setAttribute('href', url);
  link.setAttribute('download', 'växtlistan_mall.csv');
  link.style.visibility = 'hidden';

  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);

  toast.add({
    title: 'Mall nedladdad',
    description: 'CSV-mallen har laddats ner till din dator.',
    color: 'success',
  });
};
</script>

<template>
  <div class="container mx-auto px-4 py-8 max-w-6xl">
    <!-- Header -->
    <div class="md:mb-8">
      <h1 class="text-3xl font-bold mb-2">Importera Lager</h1>
      <!-- <p class="text-t-toned">Importera ditt lager från CSV, Excel eller JSON-fil</p> -->
    </div>
    <!-- Progress Steps -->
    <div class="mb-8">
      <nav aria-label="Importsteg">
        <ol class="flex items-center justify-between max-md:flex-col max-md:items-start gap-1">
          <li
            v-for="step in totalSteps"
            :key="step"
            class="flex items-center transition-all duration-200"
            :class="{
              'cursor-pointer hover:opacity-75': completedSteps.has(step) || step <= currentStep,
              'cursor-not-allowed opacity-50': !completedSteps.has(step) && step > currentStep,
            }"
            @click="goToStep(step)"
          >
            <div
              class="flex items-center justify-center w-8 h-8 rounded-full border-2 text-sm font-medium transition-all duration-200"
              :class="{
                'bg-primary border-primary text-white': step === currentStep && !stepLoading,
                'bg-primary/80 border-primary/80 text-white animate-pulse':
                  step === currentStep && stepLoading,
                'bg-primary/30 border-primary text-primary':
                  completedSteps.has(step) && step !== currentStep,
                'border-border text-t-muted': !completedSteps.has(step) && step > currentStep,
              }"
            >
              <UIcon
                v-if="step === currentStep && stepLoading"
                name="ant-design:loading-outlined"
                class="w-4 h-4 animate-spin"
              />
              <UIcon
                v-else-if="completedSteps.has(step) && step !== currentStep"
                name="i-heroicons-check"
                class="w-4 h-4"
              />
              <span v-else>{{ step }}</span>
            </div>
            <span
              class="ml-2 text-sm font-medium transition-colors duration-200"
              :class="{
                'text-primary font-semibold': step === currentStep,
                'text-primary': completedSteps.has(step) && step !== currentStep,
                'text-t-muted': !completedSteps.has(step) && step > currentStep,
              }"
            >
              {{
                step === 1
                  ? 'Ladda upp'
                  : step === 2
                  ? 'Matcha kolumner'
                  : step === 3
                  ? 'Matcha växtnamn'
                  : step === 4
                  ? 'Granska'
                  : 'Importera'
              }}
            </span>
          </li>
        </ol>
      </nav>
    </div>

    <!-- Loading Overlay -->
    <div
      v-if="stepLoading && currentStep !== 3"
      class="fixed inset-0 bg-black/10 backdrop-blur-sm z-50 flex items-center justify-center"
    >
      <div class="bg-bg rounded-lg p-6 shadow-xl">
        <div class="flex items-center space-x-4">
          <UIcon name="ant-design:loading-outlined" class="w-6 h-6 animate-spin text-primary" />
          <div>
            <p class="font-medium">Bearbetar data...</p>
            <p class="text-sm text-t-muted">Detta kan ta några sekunder</p>
          </div>
        </div>
      </div>
    </div>

    <!-- Step 1: File Upload -->
    <div v-show="currentStep === 1" class="space-y-6">
      <UCard>
        <template #header>
          <h2 class="text-xl font-semibold">Steg 1: Välj fil att importera</h2>
        </template>

        <div class="space-y-4">
          <!-- File Drop Zone -->
          <div
            class="border-2 border-dashed rounded-lg p-8 text-center transition-colors"
            :class="{
              'border-primary bg-primary/20': dragActive || stepLoading,
              'border-border': !dragActive && !stepLoading,
              'pointer-events-none opacity-75': stepLoading,
            }"
            @drop="handleDrop"
            @dragover="handleDragOver"
            @dragleave="handleDragLeave"
          >
            <div class="space-y-4">
              <UIcon
                :name="stepLoading ? 'ant-design:loading-outlined' : 'i-heroicons-cloud-arrow-up'"
                class="w-12 h-12 mx-auto text-t-toned"
                :class="{ 'animate-spin': stepLoading }"
              />

              <div>
                <p class="text-lg font-medium">
                  {{ stepLoading ? 'Bearbetar fil...' : 'Dra och släpp din fil här' }}
                </p>
                <p class="text-t-muted">
                  {{
                    stepLoading ? 'Detta tar bara några sekunder' : 'eller klicka för att välja fil'
                  }}
                </p>
              </div>

              <UButton
                variant="outline"
                class="mt-4"
                :disabled="stepLoading"
                :loading="stepLoading"
                loading-icon="ant-design:loading-outlined"
                @click="fileInput?.click()"
              >
                {{ stepLoading ? 'Bearbetar...' : 'Välj fil' }}
              </UButton>

              <input
                ref="fileInput"
                type="file"
                accept=".csv,.xlsx,.xls,.json"
                class="hidden"
                @change="handleFileSelect"
              />
            </div>
          </div>

          <!-- File Info -->
          <div v-if="selectedFile" class="bg-primary/20 border border-primary rounded-lg p-4">
            <div class="flex items-center space-x-2">
              <UIcon name="i-heroicons-document-text" class="w-5 h-5 text-primary" />
              <span class="font-medium text-green-800 dark:text-green-200">
                {{ selectedFile.name }}
              </span>
              <span class="text-primary"> ({{ (selectedFile.size / 1024).toFixed(1) }} KB) </span>
            </div>
          </div>
          <!-- Supported Formats -->
          <UCard>
            <template #header>
              <div class="flex items-center justify-between">
                <h3 class="text-lg font-medium">Stödda filformat</h3>
                <UButton
                  variant="outline"
                  size="sm"
                  icon="i-heroicons-arrow-down-tray"
                  @click="downloadTemplate"
                  class="max-md:hidden"
                >
                  Ladda ner exempel CSV-mall
                </UButton>
              </div>
            </template>

            <div class="grid grid-cols-2 md:grid-cols-3 gap-4">
              <div class="text-center">
                <UIcon
                  name="i-heroicons-document-text"
                  class="w-8 h-8 mx-auto md:mb-2 text-secondary"
                />
                <p class="font-medium">CSV</p>
                <p class="text-sm text-t-toned">.csv filer</p>
              </div>

              <div class="text-center">
                <UIcon
                  name="i-heroicons-table-cells"
                  class="w-8 h-8 mx-auto md:mb-2 text-primary"
                />
                <p class="font-medium">Excel</p>
                <p class="text-sm text-t-toned">.xlsx, .xls filer</p>
              </div>

              <div class="text-center">
                <UIcon name="i-heroicons-code-bracket" class="w-8 h-8 mx-auto md:mb-2 text-error" />
                <p class="font-medium">JSON</p>
                <p class="text-sm text-t-toned">Array av objekt</p>
              </div>
            </div>
          </UCard>

          <!-- Import Tips -->
          <UCard>
            <template #header>
              <h3 class="text-lg font-medium">Viktigt att tänka på</h3>
            </template>

            <div class="space-y-3 text-sm">
              <div class="flex items-start space-x-2">
                <UIcon
                  name="i-heroicons-check-circle"
                  class="w-4 h-4 text-primary mt-0.5 flex-shrink-0"
                />
                <p>
                  Använd hela vetenskapliga växtnamn (t.ex. "Acer palmatum 'Osakazuki'"), inga
                  förkortningar eller specialkaraktärer förutom ' och ()
                </p>
              </div>

              <div class="flex items-start space-x-2">
                <UIcon
                  name="i-heroicons-check-circle"
                  class="w-4 h-4 text-primary mt-0.5 flex-shrink-0"
                />
                <p>Kontrollera att lagerantal är numeriska värden</p>
              </div>

              <div class="flex items-start space-x-2">
                <UIcon
                  name="i-heroicons-check-circle"
                  class="w-4 h-4 text-primary mt-0.5 flex-shrink-0"
                />
                <p>Priser ska anges utan valutasymbol (t.ex. "299" istället för "299 kr")</p>
              </div>

              <div class="flex items-start space-x-2">
                <UIcon
                  name="i-heroicons-check-circle"
                  class="w-4 h-4 text-primary mt-0.5 flex-shrink-0"
                />
                <p>Höjden ska anges utan enhet (t.ex "120-140" istället för "120-140 cm")</p>
              </div>

              <div class="flex items-start space-x-2">
                <UIcon
                  name="i-heroicons-check-circle"
                  class="w-4 h-4 text-primary mt-0.5 flex-shrink-0"
                />
                <p>Krukstorlek ska anges i <i>C</i> eller <i>P</i> format (t.ex "C5" eller "P9")</p>
              </div>

              <div class="flex items-start space-x-2">
                <UIcon
                  name="i-heroicons-check-circle"
                  class="w-4 h-4 text-primary mt-0.5 flex-shrink-0"
                />
                <p>Excel-filer ska ha rubriker på första raden</p>
              </div>
            </div>
          </UCard>
        </div>
      </UCard>
    </div>

    <!-- Step 2: Column Mapping -->
    <div v-show="currentStep === 2" class="space-y-6">
      <UCard>
        <template #header>
          <h2 class="text-xl font-semibold">Steg 2: Matcha kolumner</h2>
          <p class="text-t-toned">
            Välj vilka kolumner i din fil som motsvarar databasens kolumner
          </p>
        </template>

        <div class="space-y-6">
          <!-- Column Mapping -->
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <div class="space-y-4">
              <h3 class="text-lg font-medium">Välj matchande kolumn</h3>

              <div v-for="field in requiredFields" :key="field.key" class="space-y-2">
                <label class="block text-sm font-medium">
                  {{ field.label }}
                  <span v-if="field.required" class="text-error">*</span>
                </label>
                <USelect
                  v-model="columnMapping[field.key]"
                  :items="[...headers.map((h) => ({ value: h, label: h }))]"
                  :placeholder="`Välj kolumn för ${field.label}`"
                  class="w-56"
                />
              </div>
            </div>

            <!-- Data Preview -->
            <div class="space-y-4">
              <h3 class="text-lg font-medium">Förhandsvisning av uppladdad data</h3>

              <div class="border border-border rounded-lg overflow-hidden">
                <div class="overflow-x-auto preview-table-scroll">
                  <table class="min-w-full divide-y divide-border">
                    <thead class="bg-bg-elevated">
                      <tr>
                        <th
                          v-for="header in headers"
                          :key="header"
                          class="px-3 py-2 text-left text-xs font-medium text-t-toned tracking-wider"
                        >
                          {{ header }}
                        </th>
                      </tr>
                    </thead>
                    <tbody class="divide-y divide-border">
                      <tr v-for="(row, index) in previewData" :key="index">
                        <td
                          v-for="header in headers"
                          :key="header"
                          class="px-3 py-2 text-sm text-gray-900 dark:text-white"
                        >
                          {{ row[header] || '-' }}
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </div>
              </div>

              <p class="text-sm text-t-muted">
                Visar första {{ Math.min(previewData.length, 5) }} raderna av
                {{ rawData.length }} totalt
              </p>
            </div>
          </div>
          <!-- Action Buttons -->
          <div class="flex justify-between">
            <UButton variant="outline" @click="goToStep(1)"> Tillbaka </UButton>

            <UButton
              :disabled="!canProceedToValidation"
              :loading="stepLoading"
              loading-icon="ant-design:loading-outlined"
              @click="validatePlants"
            >
              Validera växter
            </UButton>
          </div>
        </div>
      </UCard>
    </div>
    <!-- Step 3: Plant Validation (Loading) -->
    <div v-show="currentStep === 3" class="space-y-6">
      <UCard>
        <template #header>
          <h2 class="text-xl font-semibold">Steg 3: Validerar växter...</h2>
        </template>

        <div class="py-8">
          <!-- Progress indicator -->
          <div class="text-center mb-6">
            <UIcon
              name="ant-design:loading-outlined"
              class="w-8 h-8 mx-auto mb-4 animate-spin text-primary"
            />
            <p class="text-lg font-medium mb-2">Validerar växtnamn mot databasen</p>
            <p class="text-t-tone mb-4">
              {{ validationProgress.plantsProcessed }} av
              {{ validationProgress.totalPlants }} växter validerade
              <span v-if="validationProgress.totalBatches > 0" class="text-sm">
                (Batch {{ validationProgress.currentBatch }}/{{ validationProgress.totalBatches }})
              </span>
            </p>
          </div>

          <!-- Progress bar -->
          <div class="w-full bg-bg-elevated rounded-full h-3 mb-4">
            <div
              class="bg-primary h-3 rounded-full transition-all duration-300 ease-out"
              :style="{
                width:
                  validationProgress.totalPlants > 0
                    ? `${
                        (validationProgress.plantsProcessed / validationProgress.totalPlants) * 100
                      }%`
                    : '0%',
              }"
            ></div>
          </div>

          <!-- Current progress info -->
          <div class="text-center text-sm text-t-muted space-y-2">
            <p v-if="validationProgress.currentPlant">
              🔍 Validerar:
              <span class="font-medium text-t-main">
                {{ validationProgress.currentPlant }}
              </span>
            </p>

            <!-- Live validation stats -->
            <div v-if="validatedPlants.length > 0" class="flex justify-center gap-4 text-xs">
              <span class="text-primary">
                ✓ {{ validatedPlants.filter((p) => p.status === 'found').length }} hittade
              </span>
              <span class="text-error">
                ⚠ {{ validatedPlants.filter((p) => p.status === 'notFound').length }} behöver
                granskas
              </span>
              <span class="text-t-toned">
                ⏭ {{ validatedPlants.filter((p) => p.status === 'skip').length }} hoppade över
              </span>
            </div>

            <p class="text-t-toned">Processering kan ta ett tag beroende på antalet växter</p>
          </div>
        </div>
      </UCard>
    </div>

    <!-- Step 4: Review and Manual Selection -->
    <div v-show="currentStep === 4" class="space-y-6">
      <UCard>
        <template #header>
          <h2 class="text-xl font-semibold">Steg 4: Granska och välj växter</h2>
          <p class="text-t-toned">
            Kontrollera automatisk matchning och välj växter för importering
          </p>
        </template>

        <!-- Validation Summary -->
        <div class="mb-6">
          <div class="grid grid-cols-2 lg:grid-cols-4 gap-4">
            <div class="bg-primary-bg p-4 rounded-lg text-center">
              <p class="text-2xl font-bold text-primary">{{ validationSummary.found }}</p>
              <p class="text-sm text-primary/80">Automatiskt hittade</p>
            </div>

            <div class="bg-secondary-bg p-4 rounded-lg text-center">
              <p class="text-2xl font-bold text-secondary">{{ validationSummary.manual }}</p>
              <p class="text-sm text-secondary/80">Manuellt valda</p>
            </div>

            <div class="bg-error-bg p-4 rounded-lg text-center">
              <p class="text-2xl font-bold text-error">{{ validationSummary.notFound }}</p>
              <p class="text-sm text-error/80">Behöver granskas</p>
            </div>

            <div class="bg-bg-elevated p-4 rounded-lg text-center">
              <p class="text-2xl font-bold">{{ validationSummary.skip }}</p>
              <p class="text-sm text-mute">Hoppa över</p>
            </div>
          </div>
        </div>

        <!-- Plant List -->
        <div class="space-y-4 max-h-[80vh] overflow-y-auto">
          <div
            v-for="(plant, index) in validatedPlants"
            :key="index"
            class="border rounded-lg p-4"
            :class="{
              'border-primary bg-primary-bg': plant.status === 'found',
              'border-secondary bg-secondary-bg': plant.status === 'manual',
              'border-error bg-error-bg': plant.status === 'notFound',
              'border-border bg-bg-elevated text-t-toned': plant.status === 'skip',
            }"
          >
            <div class="flex items-start justify-between max-md:flex-col max-md:gap-4">
              <div class="flex-1 max-md:w-full">
                <h4 class="font-medium">
                  {{ plant.original[columnMapping.name] }}
                </h4>

                <!-- Show sanitized version if different from original -->
                <!-- <div
                  v-if="
                    sanitizePlantName(plant.original[columnMapping.name]) !==
                    plant.original[columnMapping.name]
                  "
                  class="text-sm mt-1"
                >
                  Söktes som: "{{ sanitizePlantName(plant.original[columnMapping.name]) }}"
                </div> -->

                <div class="text-sm text-t-toned mt-1">
                  Lager: {{ sanitizeNumericValue(plant.original[columnMapping.stock]) }}
                  <span v-if="columnMapping.price && plant.original[columnMapping.price]">
                    | Pris: {{ sanitizeNumericValue(plant.original[columnMapping.price]) }} kr
                  </span>
                  <span v-if="columnMapping.pot && plant.original[columnMapping.pot]">
                    | Kruka: {{ sanitizeTextValue(plant.original[columnMapping.pot]) }}
                  </span>
                  <span v-if="columnMapping.height && plant.original[columnMapping.height]">
                    | Höjd: {{ sanitizeTextValue(plant.original[columnMapping.height]) }}
                  </span>
                </div>

                <!-- Found Match -->
                <div v-if="plant.status === 'found' && plant.facitMatch" class="mt-2 text-sm">
                  <span class="text-primary font-medium">✓ Hittad:</span>
                  {{ plant.facitMatch.name }}
                  <span v-if="plant.facitMatch.sv_name" class="text-t-toned ml-1">
                    {{ plant.facitMatch.sv_name }}
                  </span>
                </div>
                <!-- Manual Selection -->
                <div v-if="plant.status === 'manual' && plant.selectedFacitId" class="mt-2 text-sm">
                  <span class="text-secondary font-medium">✓ Vald manuellt:</span>
                  <div class="mt-1 p-2 rounded border border-secondary">
                    <div v-if="selectedPlantDetails.get(index)" class="font-medium">
                      {{ selectedPlantDetails.get(index).name }}
                      <span
                        v-if="selectedPlantDetails.get(index).sv_name"
                        class="text-t-toned ml-1"
                      >
                        ({{ selectedPlantDetails.get(index).sv_name }})
                      </span>
                    </div>
                    <div v-else class="text-t-toned">ID: {{ plant.selectedFacitId }}</div>
                  </div>
                </div>

                <!-- Skip Status -->
                <div v-if="plant.status === 'skip'" class="mt-2 text-sm">
                  <span class="text-t-toned font-medium">⏭ Hoppas över</span>
                </div>

                <!-- Suggestions -->
                <div
                  v-if="plant.status === 'notFound' && plant.suggestions.length > 0"
                  class="mt-2"
                >
                  <p class="text-sm font-medium text-error mb-2">Möjliga träffar:</p>
                  <div class="space-y-1">
                    <button
                      v-for="suggestion in plant.suggestions.slice(0, 3)"
                      :key="suggestion.id"
                      class="block w-full text-left text-sm p-2 rounded border border-error hover:bg-error/10 transition-colors"
                      @click="selectPlantForRow(index, suggestion.id)"
                    >
                      {{ suggestion.name }}
                      <span v-if="suggestion.sv_name" class="text-t-toned">
                        ({{ suggestion.sv_name }})
                      </span>
                    </button>
                  </div>
                </div>
              </div>
              <!-- Actions -->
              <div class="flex space-x-2 ml-4 max-md:ml-auto">
                <!-- For plants not found - show search and skip -->
                <template v-if="plant.status === 'notFound'">
                  <UButton
                    size="sm"
                    variant="solid"
                    icon="i-heroicons-magnifying-glass"
                    @click="openPlantPicker(index)"
                  >
                    Sök
                  </UButton>
                  <UButton
                    size="sm"
                    variant="subtle"
                    color="neutral"
                    icon="material-symbols:cancel-outline-rounded"
                    @click="skipPlantRow(index)"
                  >
                    Hoppa över
                  </UButton>
                </template>

                <!-- For manually selected plants - show change and revert -->
                <template v-if="plant.status === 'manual'">
                  <UButton
                    size="sm"
                    variant="solid"
                    color="info"
                    icon="i-heroicons-pencil"
                    @click="openPlantPicker(index)"
                  >
                    Ändra
                  </UButton>
                  <UButton
                    size="sm"
                    variant="solid"
                    color="warning"
                    icon="i-heroicons-arrow-uturn-left"
                    @click="revertPlantRow(index)"
                  >
                    Ångra
                  </UButton>
                </template>

                <!-- For skipped plants - show revert to allow re-selection -->
                <template v-if="plant.status === 'skip'">
                  <UButton
                    size="sm"
                    variant="solid"
                    color="info"
                    icon="i-heroicons-arrow-uturn-left"
                    @click="revertPlantRow(index)"
                  >
                    Inkludera
                  </UButton>
                </template>

                <!-- For automatically found plants - show option to change or skip -->
                <template v-if="plant.status === 'found'">
                  <UButton
                    size="sm"
                    variant="solid"
                    color="info"
                    icon="i-heroicons-pencil"
                    @click="openPlantPicker(index)"
                  >
                    Ändra
                  </UButton>
                  <UButton
                    size="sm"
                    variant="subtle"
                    color="neutral"
                    icon="material-symbols:cancel-outline-rounded"
                    @click="skipPlantRow(index)"
                  >
                    Hoppa över
                  </UButton>
                </template>
              </div>
            </div>
          </div>
        </div>
        <!-- Action Buttons -->
        <div class="flex justify-between mt-6">
          <UButton variant="outline" :disabled="importing" @click="goToStep(2)"> Tillbaka </UButton>

          <UButton
            :disabled="!canProceedToImport || importing"
            :loading="importing"
            loading-icon="ant-design:loading-outlined"
            @click="performImport"
          >
            <span v-if="importing"> Importerar växter... </span>
            <span v-else>
              Importera ({{ validationSummary.found + validationSummary.manual }} växter)
            </span>
          </UButton>
        </div>
      </UCard>
    </div>

    <!-- Step 5: Import Results -->
    <div v-show="currentStep === 5" class="space-y-6">
      <UCard>
        <template #header>
          <h2 class="text-xl font-semibold">Import slutförd 🎉🎉</h2>
        </template>

        <div class="space-y-6">
          <!-- Import Progress -->
          <div v-if="importing" class="space-y-4">
            <div class="flex items-center justify-between">
              <span>Importerar växter...</span>
              <span>{{ Math.round(importProgress) }}%</span>
            </div>
            <UProgress :value="importProgress" class="w-full" />
          </div>

          <!-- Results -->
          <div v-if="!importing" class="space-y-4">
            <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div class="bg-primary-bg p-4 rounded-lg text-center">
                <p class="text-2xl font-bold text-primary">{{ importResults.success }}</p>
                <p class="text-sm text-primary/80">Importerade</p>
              </div>

              <div class="bg-error-bg p-4 rounded-lg text-center">
                <p class="text-2xl font-bold text-error">{{ importResults.failed }}</p>
                <p class="text-sm text-error/80">Misslyckades</p>
              </div>

              <div class="bg-bg-elevated p-4 rounded-lg text-center">
                <p class="text-2xl font-bold">{{ importResults.skipped }}</p>
                <p class="text-sm text-t-toned">Hoppade över</p>
              </div>
            </div>

            <!-- Errors -->
            <div v-if="importResults.errors.length > 0" class="space-y-2">
              <h3 class="font-medium text-red-800 dark:text-red-200">Fel som uppstod:</h3>
              <div class="max-h-40 overflow-y-auto space-y-1">
                <p
                  v-for="(error, index) in importResults.errors"
                  :key="index"
                  class="text-sm text-red-600 dark:text-red-400"
                >
                  {{ error }}
                </p>
              </div>
            </div>

            <!-- Actions -->
            <div class="flex space-x-4">
              <UButton @click="router.push('/plantskola-admin/lager')"> Visa lager </UButton>

              <UButton variant="outline" @click="resetImport"> Importera mer </UButton>
            </div>
          </div>
        </div>
      </UCard>
    </div>
    <!-- Plant Picker Modal -->
    <UModal v-model:open="plantPickerModal" class="p-8">
      <template #content>
        <div class="flex items-center justify-between w-full mb-4">
          <h3 class="text-lg font-semibold">
            {{
              selectedRowForPicker !== null &&
              validatedPlants[selectedRowForPicker]?.status === 'manual'
                ? 'Ändra vald växt'
                : 'Välj växt från databasen'
            }}
          </h3>
          <UButton
            color="neutral"
            variant="ghost"
            icon="i-heroicons-x-mark-20-solid"
            @click="plantPickerModal = false"
          />
        </div>

        <div v-if="selectedRowForPicker !== null" class="space-y-4">
          <div class="border-2 border-primary p-3 rounded-lg">
            <p class="text-sm text-gray-600 dark:text-gray-400">
              {{
                validatedPlants[selectedRowForPicker]?.status === 'manual'
                  ? 'Ändrar selection för:'
                  : 'Söker match för:'
              }}
            </p>
            <p class="font-medium">
              {{ validatedPlants[selectedRowForPicker]?.original[columnMapping.name] }}
            </p>

            <!-- Show current selection if changing -->
            <div
              v-if="
                validatedPlants[selectedRowForPicker]?.status === 'manual' &&
                selectedPlantDetails.get(selectedRowForPicker)
              "
              class="mt-2 p-2 bg-secondary-bg rounded border-l-4 border-secondary"
            >
              <p class="text-sm text-secondary font-medium">Nuvarande val:</p>
              <p class="text-sm">
                {{ selectedPlantDetails.get(selectedRowForPicker).name }}
                <span
                  v-if="selectedPlantDetails.get(selectedRowForPicker).sv_name"
                  class="text-t-toned"
                >
                  ({{ selectedPlantDetails.get(selectedRowForPicker).sv_name }})
                </span>
              </p>
            </div>
          </div>
          <PlantPicker :edit-value="0" :current-plant-i-d="0" @select="onPlantSelected" />
        </div>
      </template>
    </UModal>
  </div>
</template>

<style scoped>
/* Custom styles for drag and drop */
.drag-active {
  transform: scale(1.02);
}

.preview-table-scroll {
  scrollbar-width: thin;
  scrollbar-color: var(--ui-border) transparent;
}

.preview-table-scroll::-webkit-scrollbar {
  width: 8px;
  height: 8px;
}

.preview-table-scroll::-webkit-scrollbar-track {
  background: transparent;
}

.preview-table-scroll::-webkit-scrollbar-thumb {
  background-color: var(--ui-border);
  border-radius: 4px;
}

.preview-table-scroll::-webkit-scrollbar-thumb:hover {
  background-color: var(--ui-border-hover);
}

.preview-table-scroll::-webkit-scrollbar-corner {
  background: transparent;
}
</style>
