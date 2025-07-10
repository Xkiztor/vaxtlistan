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
import type {
  Totallager,
  Facit,
  PlantSearchResult,
  PlantSimilaritySearchResult,
} from '~/types/supabase-tables';

const user = useSupabaseUser();
const supabase = useSupabaseClient();
const router = useRouter();
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
const currentStep = ref(0);
const totalSteps = 4; // Reduced from 5
const stepLoading = ref(false);
const completedSteps = ref(new Set([0])); // Track which steps have been completed

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
  { key: 'private_comment', label: 'Privat kommentar', required: false },
  { key: 'id_by_plantskola', label: 'Eget ID/Artikelnummer', required: false },
];

// Custom fields functionality
const customFields = ref<Array<{ key: string; name: string; column: string }>>([]);
const showAddCustomField = ref(false);
const newCustomField = ref({ name: '', column: '' });

// Plant edit modal custom fields
const showAddCustomFieldInEdit = ref(false);
const newCustomFieldInEdit = ref({ name: '', column: '', value: '', forAll: false });
const deleteCustomFieldModal = ref({
  open: false,
  field: null as any,
  editIndex: null as number | null,
});

// State for editing field names
const editingFieldName = ref({
  isEditing: false,
  fieldKey: '',
  newName: '',
  isGlobal: false,
  editIndex: null as number | null,
});

// Plant validation - simplified for inline matching
const validatedPlants = ref<
  {
    original: any;
    facitMatch: Facit | null;
    suggestions: (PlantSearchResult & { similarity_score?: number; match_details?: string })[];
    highConfidenceSuggestions: (PlantSearchResult & {
      similarity_score?: number;
      match_details?: string;
    })[];
    lowConfidenceSuggestions: (PlantSearchResult & {
      similarity_score?: number;
      match_details?: string;
    })[];
    showAllSuggestions: boolean;
    selectedFacitId: number | null;
    selectedPlantData: Facit | null; // Store the selected plant data to display name
    status: 'found' | 'notFound' | 'manual' | 'skip';
    suggestionsLoading?: boolean; // Track if suggestions are being fetched
    hasBeenSearched?: boolean; // Track if this plant has been processed by the automatic matching
  }[]
>([]);

// Automatic matching progress tracking
const autoMatchingProgress = ref({
  isRunning: false,
  currentIndex: 0,
  totalPlants: 0,
  plantsProcessed: 0,
  currentPlant: '',
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

// Plant editing functionality
const editingPlant = ref<{
  index: number | null;
  data: {
    stock: string;
    price: string;
    pot: string;
    height: string;
    comment: string;
    private_comment: string;
    id_by_plantskola: string;
    plantSpecificFields?: Array<{ key: string; name: string; column: string }>;
    [key: string]: any; // For custom fields
  } | null;
}>({
  index: null,
  data: null,
});
const editPlantModal = ref(false);

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
    if (rawData.value.length > 0) {
      setupColumnMapping();
      // Initialize plants for review (no validation step)
      initializePlantsForReview();

      // Add a small delay for better UX
      await new Promise((resolve) => setTimeout(resolve, 200));

      completedSteps.value.add(1);
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
    // First, try to detect the delimiter by reading a sample of the file
    const reader = new FileReader();
    reader.onload = (e) => {
      const sample = (e.target?.result as string)?.slice(0, 1024) || '';

      // Count occurrences of common delimiters in the sample
      const commaCount = (sample.match(/,/g) || []).length;
      const semicolonCount = (sample.match(/;/g) || []).length;

      // Determine the most likely delimiter
      // If semicolons are more frequent than commas, use semicolon
      // Otherwise, let Papa.parse auto-detect (which defaults to comma)
      const delimiter = semicolonCount > commaCount ? ';' : undefined;

      // Parse the file with the detected delimiter
      Papa.parse(file, {
        header: true,
        skipEmptyLines: true,
        encoding: 'UTF-8',
        delimiter: delimiter, // Set delimiter if detected as semicolon
        complete: (results) => {
          if (results.errors.length > 0) {
            console.warn('CSV parsing warnings:', results.errors);
          }

          // Validate that we got meaningful data
          if (!results.data || results.data.length === 0) {
            reject(new Error('CSV-filen innehåller ingen data.'));
            return;
          }

          // Check if headers were properly detected
          if (!results.meta.fields || results.meta.fields.length === 0) {
            reject(new Error('Kunde inte identifiera kolumnrubriker i CSV-filen.'));
            return;
          }

          // Filter out completely empty rows before assigning to rawData
          const filteredData = filterEmptyRows(results.data as any[]);

          rawData.value = filteredData;
          headers.value = results.meta.fields || [];
          previewData.value = rawData.value.slice(0, 5);

          // Log detected delimiter for debugging
          console.log(`CSV parsed with delimiter: ${delimiter || 'auto-detected'}`);

          resolve();
        },
        error: (error) => {
          reject(new Error(`Fel vid CSV-parsning: ${error.message}`));
        },
      });
    };

    reader.onerror = () => {
      reject(new Error('Kunde inte läsa filen.'));
    };

    // Read first 1KB as text to detect delimiter
    reader.readAsText(file.slice(0, 1024), 'UTF-8');
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
        const dataObjects = dataRows.map((row) => {
          const obj: any = {};
          headers.value.forEach((header, index) => {
            obj[header] = row[index] || '';
          });
          return obj;
        });

        // Filter out completely empty rows before assigning to rawData
        rawData.value = filterEmptyRows(dataObjects);
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

        // Filter out completely empty rows before assigning to rawData
        rawData.value = filterEmptyRows(jsonData);
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
    } else if (
      lowerHeader.includes('id') ||
      lowerHeader.includes('artikel') ||
      lowerHeader.includes('kodnummer') ||
      lowerHeader.includes('artikelnummer') ||
      lowerHeader.includes('kod') ||
      lowerHeader.includes('referens') ||
      lowerHeader.includes('sku') ||
      lowerHeader.includes('produktnummer')
    ) {
      mapping['id_by_plantskola'] = header;
    }
  });
  columnMapping.value = mapping;
};

// Custom fields management
const addCustomField = () => {
  if (!newCustomField.value.name.trim() || !newCustomField.value.column) return;

  customFields.value.push({
    key: `${newCustomField.value.name}-${Date.now()}`,
    name: newCustomField.value.name,
    column: newCustomField.value.column,
  });

  showAddCustomField.value = false;
  newCustomField.value = { name: '', column: '' };
};

const removeCustomField = (index: number) => {
  const field = customFields.value[index];
  customFields.value.splice(index, 1);

  // Remove this field from all plants' data as well
  validatedPlants.value.forEach((plant) => {
    if (plant.original[field.column]) {
      delete plant.original[field.column];
    }
  });
};

// Custom field management in edit modal
// Handle column change in edit modal custom field
const onColumnChangeInEdit = () => {
  // Auto-populate value with data from selected column for current plant
  if (newCustomFieldInEdit.value.column && editingPlant.value?.index !== null) {
    const plant = validatedPlants.value[editingPlant.value.index];
    if (plant?.original) {
      const columnValue = plant.original[newCustomFieldInEdit.value.column];
      newCustomFieldInEdit.value.value = columnValue || '';
    }
  } else {
    // Clear value and reset forAll flag if no column selected
    newCustomFieldInEdit.value.value = '';
    newCustomFieldInEdit.value.forAll = false;
  }
};

const addCustomFieldToEditPlant = () => {
  if (!newCustomFieldInEdit.value.name.trim()) return;

  const fieldKey = `custom_${newCustomFieldInEdit.value.name
    .replace(/\s+/g, '_')
    .toLowerCase()}_${Date.now()}`;
  const newField = {
    key: fieldKey,
    name: newCustomFieldInEdit.value.name,
    column: newCustomFieldInEdit.value.column || '',
  };

  if (newCustomFieldInEdit.value.forAll && newCustomFieldInEdit.value.column) {
    // Add to global custom fields (only if column is specified)
    customFields.value.push({
      key: fieldKey,
      name: newCustomFieldInEdit.value.name,
      column: newCustomFieldInEdit.value.column,
    });

    // Add to all plants' edit data if currently editing
    if (editingPlant.value.data) {
      editingPlant.value.data[fieldKey] = newCustomFieldInEdit.value.value || '';
    }
  } else {
    // Add only to current plant's edit data
    if (editingPlant.value.data) {
      if (!Array.isArray(editingPlant.value.data.plantSpecificFields)) {
        editingPlant.value.data.plantSpecificFields = [];
      }
      editingPlant.value.data.plantSpecificFields.push(newField);
      editingPlant.value.data[fieldKey] = newCustomFieldInEdit.value.value || '';
    }
  }

  showAddCustomFieldInEdit.value = false;
  newCustomFieldInEdit.value = { name: '', column: '', value: '', forAll: false };
};

const openDeleteCustomFieldModal = (editIndex: number, field: any) => {
  deleteCustomFieldModal.value = {
    open: true,
    field,
    editIndex,
  };
};

const deleteCustomFieldForAll = () => {
  const field = deleteCustomFieldModal.value.field;
  if (!field) return;

  // Remove from global custom fields
  const globalIndex = customFields.value.findIndex((f) => f.key === field.key);
  if (globalIndex !== -1) {
    customFields.value.splice(globalIndex, 1);
  }

  // Remove from all plants' data
  validatedPlants.value.forEach((plant) => {
    if (plant.original[field.column]) {
      delete plant.original[field.column];
    }
  });

  // Remove from current edit data
  if (editingPlant.value.data && editingPlant.value.data[field.key] !== undefined) {
    delete editingPlant.value.data[field.key];
  }

  deleteCustomFieldModal.value = { open: false, field: null, editIndex: null };
};

const deleteCustomFieldForThisPlant = () => {
  const field = deleteCustomFieldModal.value.field;
  const editIndex = deleteCustomFieldModal.value.editIndex;

  if (!field || editIndex === null) return;

  // Remove from current plant's plant-specific fields
  if (Array.isArray(editingPlant.value.data?.plantSpecificFields)) {
    editingPlant.value.data.plantSpecificFields.splice(editIndex, 1);
  }

  // Remove from current edit data
  if (editingPlant.value.data && editingPlant.value.data[field.key] !== undefined) {
    delete editingPlant.value.data[field.key];
  }

  deleteCustomFieldModal.value = { open: false, field: null, editIndex: null };
};

// Functions for editing field names
const startEditingFieldName = (field: any, isGlobal: boolean, editIndex: number | null = null) => {
  editingFieldName.value = {
    isEditing: true,
    fieldKey: field.key,
    newName: field.name,
    isGlobal,
    editIndex,
  };
};

const cancelEditingFieldName = () => {
  editingFieldName.value = {
    isEditing: false,
    fieldKey: '',
    newName: '',
    isGlobal: false,
    editIndex: null,
  };
};

const saveFieldNameEdit = () => {
  const { fieldKey, newName, isGlobal, editIndex } = editingFieldName.value;

  if (!fieldKey || !newName.trim()) return;

  if (isGlobal) {
    // Update global custom field name
    const globalField = customFields.value.find((f) => f.key === fieldKey);
    if (globalField) {
      globalField.name = newName.trim();
    }
  } else {
    // Update plant-specific field name
    if (Array.isArray(editingPlant.value.data?.plantSpecificFields) && editIndex !== null) {
      const plantField = editingPlant.value.data.plantSpecificFields[editIndex];
      if (plantField) {
        plantField.name = newName.trim();
      }
    }
  }

  cancelEditingFieldName();
};

const getAvailableColumnsForCustomFields = () => {
  // Get columns that are not used by required fields or other custom fields
  const usedColumns = new Set([
    ...Object.values(columnMapping.value),
    ...customFields.value.map((field) => field.column),
  ]);

  return headers.value.filter((header) => !usedColumns.has(header));
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
      .replace(/[""`´]/g, "'") // Replace various quote types with standard apostrophe
      .replace(/[\u2018\u2019]/g, "'") // Replace smart quotes
      // Remove unnecessary punctuation but keep apostrophes and hyphens
      .replace(/[^\w\s''\-×.()]/g, '')
      .replace('×', 'x') // Replace multiplication sign with 'x'
      // Clean up any remaining double spaces
      .replace(/\s+/g, ' ')
      .trim()
  );
};

// Function to check if a row is completely empty
const isRowEmpty = (row: any): boolean => {
  if (!row || typeof row !== 'object') return true;

  // Check if all values in the row are empty, null, undefined, or only whitespace
  return Object.values(row).every((value) => {
    if (value === null || value === undefined) return true;
    if (typeof value === 'string') return value.trim() === '';
    if (typeof value === 'number') return false; // Numbers (even 0) are not considered empty
    if (typeof value === 'boolean') return false; // Booleans are not considered empty
    return !value; // For other types, use truthiness
  });
};

// Function to filter out empty rows from parsed data
const filterEmptyRows = (data: any[]): any[] => {
  const filteredData = data.filter((row) => !isRowEmpty(row));

  // Log the filtering result for debugging
  const removedCount = data.length - filteredData.length;
  if (removedCount > 0) {
    console.log(
      `Filtered out ${removedCount} empty rows from imported data. Remaining: ${filteredData.length} rows`
    );
  }

  return filteredData;
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

// Initialize plants for review without validation step
const initializePlantsForReview = () => {
  validatedPlants.value = rawData.value.map((row) => {
    const rawPlantName = row[columnMapping.value.name]?.toString().trim() || '';
    const sanitizedPlantName = sanitizePlantName(rawPlantName); // Skip plants with invalid names
    if (!sanitizedPlantName || sanitizedPlantName.length < 2) {
      return {
        original: row,
        facitMatch: null,
        suggestions: [],
        highConfidenceSuggestions: [],
        lowConfidenceSuggestions: [],
        showAllSuggestions: false,
        selectedFacitId: null,
        selectedPlantData: null, // Initialize selected plant data
        status: 'skip' as const,
        suggestionsLoading: false,
        hasBeenSearched: true, // Skip status means it's been "processed"
      };
    } // Initialize all plants as not found - matching will happen inline
    return {
      original: row,
      facitMatch: null,
      suggestions: [],
      highConfidenceSuggestions: [],
      lowConfidenceSuggestions: [],
      showAllSuggestions: false,
      selectedFacitId: null,
      selectedPlantData: null, // Initialize selected plant data
      status: 'notFound' as const,
      suggestionsLoading: false,
      hasBeenSearched: false,
    };
  });
};

// Client-side plant matching using advanced similarity calculation
const searchPlantMatches = async (
  plantName: string
): Promise<(PlantSearchResult & { similarity_score: number; match_details: string })[]> => {
  if (!plantName || plantName.length < 2) {
    return [];
  }

  try {
    console.log(`Searching for plant matches using client-side similarity: "${plantName}"`);
    const { findBestMatches, convertToPlantSearchResult } = usePlantSimilarity();

    // Find matches using the new similarity algorithm
    const matchResult = await findBestMatches(plantName, {
      limit: 10,
      minimumScore: 0.3,
      includeStrictMatchesOnly: false,
    });

    // Combine strict matches and suggestions
    const allMatches = [...matchResult.strictMatches, ...matchResult.suggestions];

    if (allMatches.length === 0) {
      console.log(`No matches found for "${plantName}"`);
      return [];
    }

    console.log(
      `Found ${allMatches.length} matches for "${plantName}" (${matchResult.strictMatches.length} strict matches)`
    );

    // Convert to PlantSearchResult format with similarity scores
    const convertedResults = allMatches.map((match) => convertToPlantSearchResult(match));

    console.log(`Returning ${convertedResults.length} sorted matches`);
    return convertedResults;
  } catch (error) {
    console.error('Error in searchPlantMatches:', error);
    return [];
  }
};

// Load suggestions for a specific plant row
const loadSuggestionsForPlant = async (rowIndex: number) => {
  const plant = validatedPlants.value[rowIndex];
  if (!plant || plant.suggestionsLoading) {
    return;
  }

  const plantName = plant.original[columnMapping.value.name]?.toString().trim() || '';
  const sanitizedPlantName = sanitizePlantName(plantName);
  if (!sanitizedPlantName || sanitizedPlantName.length < 2) {
    plant.status = 'skip';
    plant.hasBeenSearched = true; // Mark as processed since we determined it should be skipped
    return;
  }

  plant.suggestionsLoading = true;

  try {
    const matches = await searchPlantMatches(sanitizedPlantName);

    console.log('Loaded suggestions for plant:', sanitizedPlantName, matches);
    if (matches.length > 0) {
      // Separate high confidence (85%+) and low confidence matches
      const highConfidence = matches.filter((match: any) => (match.similarity_score || 0) >= 0.85);
      const lowConfidence = matches.filter((match: any) => (match.similarity_score || 0) < 0.85);

      // Check if we have a strict match (similarity >= 0.95)
      const strictMatch = matches.find((match: any) => (match.similarity_score || 0) >= 0.95);

      if (strictMatch) {
        // Auto-select strict matches (0.95 or higher similarity)
        plant.facitMatch = strictMatch as any;
        plant.selectedFacitId = strictMatch.id;
        plant.status = 'found';
        plant.suggestions = matches; // Keep all suggestions for user review
        plant.highConfidenceSuggestions = highConfidence;
        plant.lowConfidenceSuggestions = lowConfidence;
        plant.showAllSuggestions = false;
        console.log(
          `Auto-selected strict match for "${sanitizedPlantName}": ${
            strictMatch.name
          } (similarity: ${(strictMatch as any).similarity_score?.toFixed(3) || 'N/A'})`
        );
      } else {
        // Show suggestions for manual selection
        plant.suggestions = matches;
        plant.highConfidenceSuggestions = highConfidence;
        plant.lowConfidenceSuggestions = lowConfidence;
        plant.showAllSuggestions = highConfidence.length === 0; // Show all if no high confidence matches
        plant.status = 'notFound';
        console.log(
          `Found ${matches.length} suggestions for "${sanitizedPlantName}" (${
            highConfidence.length
          } high confidence, ${lowConfidence.length} low confidence) (best similarity: ${
            (matches[0] as any)?.similarity_score?.toFixed(3) || 'N/A'
          })`
        );
      }
    } else {
      // No matches found
      plant.suggestions = [];
      plant.status = 'notFound';
      console.log(`No matches found for "${sanitizedPlantName}"`);
    }
  } catch (error) {
    console.error(`Error loading suggestions for "${sanitizedPlantName}":`, error);
    plant.suggestions = [];
    plant.status = 'notFound';
  } finally {
    plant.suggestionsLoading = false;
    plant.hasBeenSearched = true; // Mark as searched regardless of outcome
  }
};

// Automatic batch matching for all plants
const startAutomaticMatching = async () => {
  if (autoMatchingProgress.value.isRunning) {
    console.warn('Automatic matching already in progress');
    return;
  }
  // Reset any plants that are in "notFound" status to prepare for re-matching
  validatedPlants.value.forEach((plant) => {
    if (plant.status === 'notFound' && plant.suggestions.length === 0) {
      plant.suggestions = [];
      plant.suggestionsLoading = false;
      plant.hasBeenSearched = false; // Reset search status for re-matching
    }
  });

  // Initialize progress tracking
  autoMatchingProgress.value = {
    isRunning: true,
    currentIndex: 0,
    totalPlants: validatedPlants.value.length,
    plantsProcessed: 0,
    currentPlant: '',
  };

  console.log(`Starting automatic matching for ${autoMatchingProgress.value.totalPlants} plants`);

  try {
    // Process plants sequentially
    for (let i = 0; i < validatedPlants.value.length; i++) {
      const plant = validatedPlants.value[i];

      // Update progress
      autoMatchingProgress.value.currentIndex = i;
      autoMatchingProgress.value.currentPlant =
        plant.original[columnMapping.value.name]?.toString().trim() || `Plant ${i + 1}`;

      // Skip already processed plants or plants that should be skipped
      if (plant.status === 'skip' || plant.status === 'found' || plant.status === 'manual') {
        autoMatchingProgress.value.plantsProcessed++;
        continue;
      }

      // Match this plant
      await loadSuggestionsForPlant(i);

      // Update progress
      autoMatchingProgress.value.plantsProcessed++;

      // Add a small delay to prevent overwhelming the database and provide visual feedback
      await new Promise((resolve) => setTimeout(resolve, 200));
    }

    console.log('Automatic matching completed');

    // Show completion toast
    const summary = validationSummary.value;
    toast.add({
      title: 'Automatisk matchning slutförd',
      description: `${summary.found} hittade, ${summary.notFound} behöver granskas`,
      color: 'primary',
    });
  } catch (error) {
    console.error('Error during automatic matching:', error);
    toast.add({
      title: 'Fel vid automatisk matchning',
      description: 'Ett fel uppstod under den automatiska matchningen.',
      color: 'error',
    });
  } finally {
    // Reset progress tracking
    autoMatchingProgress.value.isRunning = false;
    autoMatchingProgress.value.currentIndex = 0;
    autoMatchingProgress.value.currentPlant = '';
  }
};

// Manual plant selection
const plantPickerModal = ref(false);
const selectedRowForPicker = ref<number | null>(null);

const openPlantPicker = (rowIndex: number) => {
  selectedRowForPicker.value = rowIndex;
  plantPickerModal.value = true;
};

const onPlantSelected = (plantId: number, plantData?: any) => {
  if (selectedRowForPicker.value !== null) {
    selectPlantForRow(selectedRowForPicker.value, plantId, plantData);
  }

  plantPickerModal.value = false;
  selectedRowForPicker.value = null;
};

const selectPlantForRow = (rowIndex: number, facitId: number, selectedPlantData?: any) => {
  if (validatedPlants.value[rowIndex]) {
    let finalPlantId = facitId;
    let finalPlantData = selectedPlantData;

    // If we have plant data and it's a synonym, use the synonym_to_id directly
    if (selectedPlantData?.is_synonym && selectedPlantData?.synonym_to_id) {
      finalPlantId = selectedPlantData.synonym_to_id;
      console.log(
        `Selected plant "${selectedPlantData.name}" is a synonym, using target plant ID: ${finalPlantId}`
      );

      toast.add({
        title: 'Synonym ersatt',
        description: `"${selectedPlantData.name}" är en synonym. Den korrekta växten har valts automatiskt.`,
        color: 'info',
      });
    }

    validatedPlants.value[rowIndex].selectedFacitId = finalPlantId;
    validatedPlants.value[rowIndex].selectedPlantData = finalPlantData; // Store the plant data
    validatedPlants.value[rowIndex].status = 'manual';
    validatedPlants.value[rowIndex].hasBeenSearched = true; // Mark as searched since user manually selected
  }
};

const skipPlantRow = (rowIndex: number) => {
  if (validatedPlants.value[rowIndex]) {
    validatedPlants.value[rowIndex].status = 'skip';
    validatedPlants.value[rowIndex].selectedFacitId = null;
    validatedPlants.value[rowIndex].selectedPlantData = null; // Clear the selected plant data
    validatedPlants.value[rowIndex].facitMatch = null;
  }
};

const revertPlantRow = (rowIndex: number) => {
  if (validatedPlants.value[rowIndex]) {
    const plant = validatedPlants.value[rowIndex];

    plant.status = 'notFound';
    plant.selectedFacitId = null;
    plant.selectedPlantData = null; // Clear the selected plant data
    plant.hasBeenSearched = false; // Reset search status so it can be searched again

    // If this was an automatic find, we want to keep showing it as a suggestion
  }
};

// Plant parameters editing functionality
const openEditPlant = (index: number) => {
  console.log(`Opening edit modal for plant at index ${index}`);

  const plant = validatedPlants.value[index];
  if (!plant) return;

  // Initialize edit data with current values
  const editData: any = {
    stock: sanitizeNumericValue(plant.original[columnMapping.value.stock]) || '',
    price: sanitizeNumericValue(plant.original[columnMapping.value.price]) || '',
    pot: sanitizeTextValue(plant.original[columnMapping.value.pot]) || '',
    height: sanitizeTextValue(plant.original[columnMapping.value.height]) || '',
    // Always initialize comment fields, even if no column is mapped
    comment: columnMapping.value.comment
      ? sanitizeTextValue(plant.original[columnMapping.value.comment]) || ''
      : plant.original._editableComment || '',
    private_comment: columnMapping.value.private_comment
      ? sanitizeTextValue(plant.original[columnMapping.value.private_comment]) || ''
      : plant.original._editablePrivateComment || '',
    id_by_plantskola: sanitizeTextValue(plant.original[columnMapping.value.id_by_plantskola]) || '',
  };

  // Add custom fields to edit data
  customFields.value.forEach((field) => {
    editData[field.key] = sanitizeTextValue(plant.original[field.column]) || '';
  });

  // Add plant-specific custom fields (stored in the plant's original data)
  editData.plantSpecificFields = plant.original._plantSpecificFields || [];

  // Add values for plant-specific custom fields
  if (Array.isArray(editData.plantSpecificFields)) {
    editData.plantSpecificFields.forEach((field: any) => {
      editData[field.key] = plant.original[`_${field.key}`] || '';
    });
  }

  editingPlant.value = {
    index,
    data: editData,
  };

  editPlantModal.value = true;
};

const saveEditedPlant = () => {
  if (editingPlant.value.index === null || !editingPlant.value.data) return;

  const plant = validatedPlants.value[editingPlant.value.index];
  if (!plant) return;

  // Update the original data with edited values
  const data = editingPlant.value.data;

  // Update mapped columns
  if (columnMapping.value.stock) plant.original[columnMapping.value.stock] = data.stock;
  if (columnMapping.value.price) plant.original[columnMapping.value.price] = data.price;
  if (columnMapping.value.pot) plant.original[columnMapping.value.pot] = data.pot;
  if (columnMapping.value.height) plant.original[columnMapping.value.height] = data.height;
  if (columnMapping.value.id_by_plantskola)
    plant.original[columnMapping.value.id_by_plantskola] = data.id_by_plantskola;

  // Always save comment fields, either to mapped columns or internal storage
  if (columnMapping.value.comment) {
    plant.original[columnMapping.value.comment] = data.comment;
  } else {
    // Store in internal field if no column is mapped
    plant.original._editableComment = data.comment;
  }

  if (columnMapping.value.private_comment) {
    plant.original[columnMapping.value.private_comment] = data.private_comment;
  } else {
    // Store in internal field if no column is mapped
    plant.original._editablePrivateComment = data.private_comment;
  }

  // Update custom fields
  customFields.value.forEach((field) => {
    if (field.column && data[field.key] !== undefined) {
      plant.original[field.column] = data[field.key];
    }
  });

  // Save plant-specific custom fields
  if (Array.isArray(data.plantSpecificFields)) {
    plant.original._plantSpecificFields = data.plantSpecificFields;
    // Also save the values for plant-specific fields
    data.plantSpecificFields.forEach((field: any) => {
      if (data[field.key] !== undefined) {
        plant.original[`_${field.key}`] = data[field.key];
      }
    });
  }

  // Close modal and reset state
  editPlantModal.value = false;
  editingPlant.value = {
    index: null,
    data: null,
  };

  toast.add({
    title: 'Växtdata uppdaterad',
    description: 'Växtens parametrar har sparats',
    color: 'primary',
  });
};

const cancelEditPlant = () => {
  editPlantModal.value = false;
  editingPlant.value = {
    index: null,
    data: null,
  };
};

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
        // Build custom fields object
        const ownColumns: Record<string, any> = {};

        // Add global custom fields
        customFields.value.forEach((field) => {
          const value = plant.original[field.column];
          if (value !== undefined && value !== null && value !== '') {
            ownColumns[field.name] = sanitizeTextValue(value);
          }
        });

        // Add plant-specific custom fields
        if (Array.isArray(plant.original._plantSpecificFields)) {
          plant.original._plantSpecificFields.forEach((field: any) => {
            const value = plant.original[`_${field.key}`];
            if (value !== undefined && value !== null && value !== '') {
              ownColumns[field.name] = sanitizeTextValue(value);
            }
          });
        }
        const lagerData: Partial<Totallager> = {
          facit_id: plant.selectedFacitId!,
          plantskola_id: plantskola.value.id,
          name_by_plantskola: sanitizePlantName(plant.original[columnMapping.value.name] || ''),
          // Use comment from mapped column or internal storage
          comment_by_plantskola: columnMapping.value.comment
            ? sanitizeTextValue(plant.original[columnMapping.value.comment] || '')
            : sanitizeTextValue(plant.original._editableComment || ''),
          // Use private comment from mapped column or internal storage
          private_comment_by_plantskola: columnMapping.value.private_comment
            ? sanitizeTextValue(plant.original[columnMapping.value.private_comment] || '')
            : sanitizeTextValue(plant.original._editablePrivateComment || ''),
          id_by_plantskola: columnMapping.value.id_by_plantskola
            ? sanitizeTextValue(plant.original[columnMapping.value.id_by_plantskola] || '')
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
          own_columns: Object.keys(ownColumns).length > 0 ? ownColumns : null,
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

    // Calculate skipped plants (plants marked as 'skip' OR plants without a selected suggestion)
    importResults.value.skipped = validatedPlants.value.filter(
      (plant) => plant.status === 'skip' || !plant.selectedFacitId
    ).length; // Move to results step
    completedSteps.value.add(4);
    currentStep.value = 4;

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
  // Allow navigation to completed steps, the current step, or the next step
  if (completedSteps.value.has(step) || step <= currentStep.value + 1) {
    if (step !== currentStep.value) {
      if (step !== 1 && step !== 0) {
        stepLoading.value = true;
        // Add a small delay for better UX
        await new Promise((resolve) => setTimeout(resolve, 100));
      }

      currentStep.value = step;
      stepLoading.value = false;
    }
  }
};

const proceedToReview = async () => {
  if (!columnMapping.value.name) {
    toast.add({
      title: 'Saknad kolumnmappning',
      description: 'Du måste matcha växtnamn-kolumnen för att fortsätta.',
      color: 'error',
    });
    return;
  }

  // Initialize plants for review and go directly to step 3
  initializePlantsForReview();
  completedSteps.value.add(3);
  currentStep.value = 3;

  // Start automatic matching after a short delay to ensure the UI has updated
  await nextTick();
  await new Promise((resolve) => setTimeout(resolve, 100));

  // Start the automatic matching process
  startAutomaticMatching();
};

const resetImport = () => {
  currentStep.value = 0;
  stepLoading.value = false;
  completedSteps.value = new Set([0]); // Reset to only step 0 completed
  selectedFile.value = null;
  rawData.value = [];
  headers.value = [];
  previewData.value = [];
  columnMapping.value = {};
  customFields.value = []; // Reset custom fields
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
</script>

<template>
  <div class="container mx-auto px-4 py-8 max-w-6xl">
    <!-- Header -->
    <div class="md:mb-8">
      <div class="flex justify-between items-start mb-4">
        <div>
          <h1 class="text-3xl font-bold mb-2">Importera</h1>
          <!-- <p class="text-t-toned">Importera ditt lager från CSV, Excel eller JSON-fil</p> -->
        </div>
      </div>
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
                step === 0
                  ? 'Guide'
                  : step === 1
                  ? 'Ladda upp'
                  : step === 2
                  ? 'Matcha kolumner'
                  : step === 3
                  ? 'Matcha växtnamn'
                  : step === 4
                  ? 'Importera'
                  : 'Klar'
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

    <!-- Step 0: Guide and Information -->
    <div v-show="currentStep === 0" class="space-y-6">
      <UCard>
        <template #header>
          <h2 class="text-xl font-semibold">Så här funkar det</h2>
        </template>

        <div class="space-y-6">
          <!-- How it works -->
          <div class="space-y-4">
            <div class="rounded-lg space-y-4">
              <div class="flex items-start space-x-3">
                <div
                  class="text-white flex items-center justify-center w-6 h-6 rounded-full bg-primary text-sm font-medium flex-shrink-0 mt-0.5"
                >
                  1
                </div>
                <div>
                  <h4 class="font-medium">Ladda upp din fil</h4>
                  <p class="text-sm text-t-toned">
                    Ladda upp en CSV, Excel eller JSON-fil med ditt lager. Filen måste innehålla
                    växtnamn och kan innehålla ytterligare information som pris, lagerantal,
                    krukstorlek etc.
                  </p>
                </div>
              </div>

              <div class="flex items-start space-x-3">
                <div
                  class="text-white flex items-center justify-center w-6 h-6 rounded-full bg-primary text-sm font-medium flex-shrink-0 mt-0.5"
                >
                  2
                </div>
                <div>
                  <h4 class="font-medium">Matcha kolumner</h4>
                  <p class="text-sm text-t-toned">
                    Välj vilka kolumner i din fil som motsvarar våra standardfält. Du får gärna även
                    lägga till anpassade fält för extra information.
                  </p>
                </div>
              </div>
              <div class="flex items-start space-x-3">
                <div
                  class="text-white flex items-center justify-center w-6 h-6 rounded-full bg-primary text-sm font-medium flex-shrink-0 mt-0.5"
                >
                  3
                </div>
                <div>
                  <h4 class="font-medium">Växtnamn matchas automatiskt</h4>
                  <p class="text-sm text-t-toned">
                    Systemet använder avancerad algoritm som jämför olika delar av växtnamnet
                    (släkte, art, sortnamn, märkesnamn) med vårt facit. Matchningar med 95%+
                    säkerhet väljs automatiskt, medan andra föreslås för manuell granskning.
                  </p>
                </div>
              </div>

              <div class="flex items-start space-x-3">
                <div
                  class="text-white flex items-center justify-center w-6 h-6 rounded-full bg-primary text-sm font-medium flex-shrink-0 mt-0.5"
                >
                  4
                </div>
                <div>
                  <h4 class="font-medium">Granska och korrigera</h4>
                  <p class="text-sm text-t-toned">
                    För växter som inte hittas automatiskt får du förslag eller kan söka manuellt.
                    Finns inte växten i vårt facit kan du lägga till den. Du kan också välja att
                    hoppa över växter som inte ska importeras.
                  </p>
                </div>
              </div>

              <div class="flex items-start space-x-3">
                <div
                  class="text-white flex items-center justify-center w-6 h-6 rounded-full bg-primary text-sm font-medium flex-shrink-0 mt-0.5"
                >
                  5
                </div>
                <div>
                  <h4 class="font-medium">Importera till ditt lager</h4>
                  <p class="text-sm text-t-toned">
                    Alla matchade växter importeras till ditt lager och blir synliga för kunder som
                    söker efter dem på plattformen.
                  </p>
                </div>
              </div>
            </div>
          </div>

          <!-- Database validation info -->
          <div class="space-y-4">
            <div class="bg-secondary-bg/30 border border-secondary p-4 rounded-lg">
              <div class="flex items-start space-x-3">
                <UIcon
                  name="i-heroicons-information-circle"
                  class="w-5 h-5 text-secondary mt-0.5 flex-shrink-0"
                />
                <div class="space-y-2">
                  <p class="font-medium text-secondary">Varför matchar vi växtnamn?</p>
                  <div class="text-sm text-secondary space-y-1">
                    <p>
                      • <strong>Enhetlighet:</strong> Säkerställer att samma växt alltid har samma
                      namn
                    </p>
                    <p>
                      • <strong>Sökbarhet:</strong> Kunderna hittar det de söker efter med korrekta
                      växtnamn
                    </p>
                    <!-- <p>
                      • <strong>Kompatibilitet:</strong> Möjliggör jämförelser mellan olika
                      plantskolor
                    </p> -->
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- File requirements and tips -->
          <div class="space-y-4">
            <h3 class="text-lg font-medium">Viktigt att tänka på</h3>
            <div class="space-y-3 text-sm">
              <div class="flex items-start space-x-2">
                <UIcon
                  name="i-heroicons-check-circle"
                  class="w-4 h-4 text-primary mt-0.5 flex-shrink-0"
                />
                <p>
                  <strong>Växtnamn:</strong> Använd hela vetenskapliga växtnamn (t.ex. "Acer
                  palmatum 'Osakazuki'"). Undvik förkortningar och specialtecken förutom apostrof '
                  och parenteser ().
                </p>
              </div>

              <div class="flex items-start space-x-2">
                <UIcon
                  name="i-heroicons-check-circle"
                  class="w-4 h-4 text-primary mt-0.5 flex-shrink-0"
                />
                <p>
                  <strong>Numeriska värden:</strong> Lagerantal och priser ska vara rena siffror
                  utan text. T.ex. "25" istället för "25 st" och "299" istället för "299 kr".
                </p>
              </div>

              <div class="flex items-start space-x-2">
                <UIcon
                  name="i-heroicons-check-circle"
                  class="w-4 h-4 text-primary mt-0.5 flex-shrink-0"
                />
                <p>
                  <strong>Krukstorlek:</strong> Använd helst <i>C</i> och <i>P</i> formatet. T.ex.
                  "C5" eller "P9"
                </p>
              </div>

              <div class="flex items-start space-x-2">
                <UIcon
                  name="i-heroicons-check-circle"
                  class="w-4 h-4 text-primary mt-0.5 flex-shrink-0"
                />
                <p>
                  <strong>Höjd:</strong> Ange utan enheter, t.ex. "120-140" istället för "120-140
                  cm".
                </p>
              </div>

              <div class="flex items-start space-x-2">
                <UIcon
                  name="i-heroicons-check-circle"
                  class="w-4 h-4 text-primary mt-0.5 flex-shrink-0"
                />
                <p><strong>Filformat:</strong> Excel-filer ska ha rubriker på första raden.</p>
              </div>

              <div class="flex items-start space-x-2">
                <UIcon
                  name="i-heroicons-check-circle"
                  class="w-4 h-4 text-primary mt-0.5 flex-shrink-0"
                />
                <p>
                  <strong>Anpassade fält:</strong> Du kan lägga till egna fält för information som
                  ålder, stamomfrång, kön etc. Dessa sparas och visas tillsammans med
                  växtinformationen.
                </p>
              </div>
            </div>
          </div>

          <!-- Action button -->
          <div class="flex justify-end md:pt-4">
            <UButton trailing-icon="i-heroicons-arrow-right" @click="goToStep(1)">
              Börja importera
            </UButton>
          </div>
        </div>
      </UCard>
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
              <div class="flex items-center">
                <h3 class="text-lg font-medium">Stödda filformat</h3>
              </div>
            </template>

            <div class="grid grid-cols-2 md:grid-cols-3 gap-4">
              <div class="text-center">
                <UIcon
                  name="i-heroicons-document-text"
                  class="w-8 h-8 mx-auto md:mb-2 text-secondary"
                />
                <p class="font-medium">CSV</p>
                <p class="text-sm text-t-toned">.csv filer med UTF-8 kodning</p>
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
        </div>
        <div class="mt-4">
          <UButton variant="outline" @click="goToStep(0)">Tillbaka</UButton>
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
          <div class="grid grid-cols-1 lg:grid-cols-[40%_60%] gap-6">
            <div class="space-y-6">
              <!-- Standard Fields -->
              <div class="space-y-4">
                <h3 class="text-lg font-medium">Välj matchande kolumn</h3>

                <div v-for="field in requiredFields" :key="field.key" class="space-y-2">
                  <label class="block text-md font-semibold">
                    {{ field.label }}:
                    <span v-if="field.required" class="text-error">*</span>
                    <span class="block text-sm text-t-muted" v-if="field.key === 'private_comment'"
                      >Endast synligt för er</span
                    >
                  </label>
                  <div class="flex items-center">
                    <USelect
                      v-model="columnMapping[field.key]"
                      :items="[...headers.map((h) => ({ value: h, label: h }))]"
                      :placeholder="`Välj kolumn för ${field.label}`"
                      class="w-56"
                    />
                    <UButton
                      v-if="columnMapping[field.key] && field.key !== 'name'"
                      variant="outline"
                      class="ml-2"
                      icon="i-heroicons-x-mark"
                      @click="columnMapping[field.key] = ''"
                    />
                  </div>
                </div>
              </div>

              <!-- Custom Fields Section -->
              <div class="space-y-4 lg:border-t lg:border-border lg:pt-4">
                <div class="flex items-center justify-between">
                  <h3 class="text-lg font-medium">Egna fält</h3>
                  <UButton
                    v-if="getAvailableColumnsForCustomFields().length > 0 || true"
                    variant="outline"
                    size="sm"
                    icon="i-heroicons-plus"
                    @click="showAddCustomField = true"
                  >
                    Lägg till fält
                  </UButton>
                </div>
                <!-- Add Custom Field Form -->
                <div
                  v-if="showAddCustomField"
                  class="bg-bg-elevated p-4 rounded-lg border border-border space-y-3"
                >
                  <h4 class="font-medium">Nytt anpassat fält</h4>
                  <div class="space-y-2">
                    <label class="block text-sm font-medium">Fältnamn:</label>
                    <UInput
                      v-model="newCustomField.name"
                      placeholder="t.ex. 'Ålder', 'Stamomfång', 'Ursprung'"
                      class="w-full"
                    />
                  </div>
                  <div class="space-y-2">
                    <label class="block text-sm font-medium">Välj kolumn:</label>
                    <USelect
                      v-model="newCustomField.column"
                      :items="
                        getAvailableColumnsForCustomFields().map((h) => ({ value: h, label: h }))
                      "
                      placeholder="Välj kolumn från din fil"
                      class="w-full"
                    />
                  </div>
                  <div class="flex space-x-2">
                    <UButton
                      size="sm"
                      :disabled="!newCustomField.name.trim() || !newCustomField.column"
                      @click="addCustomField"
                    >
                      Lägg till
                    </UButton>
                    <UButton
                      variant="outline"
                      size="sm"
                      @click="
                        showAddCustomField = false;
                        newCustomField = { name: '', column: '' };
                      "
                    >
                      Avbryt
                    </UButton>
                  </div>
                </div>

                <!-- Existing Custom Fields -->
                <div v-if="customFields.length > 0" class="space-y-2">
                  <div
                    v-for="(field, index) in customFields"
                    :key="field.key"
                    class="flex items-center justify-between p-3 rounded-lg border border-border"
                  >
                    <div>
                      <span class="font-medium">{{ field.name }}</span>
                      <span class="text-sm text-t-toned ml-2">→ {{ field.column }}</span>
                    </div>
                    <UButton
                      variant="ghost"
                      size="sm"
                      icon="i-heroicons-trash"
                      class="text-error"
                      @click="removeCustomField(index)"
                    />
                  </div>
                </div>

                <div
                  v-if="customFields.length === 0 && !showAddCustomField"
                  class="text-sm text-t-muted"
                >
                  Här kan du lägga till egna fält från din fil eller skapa egna fält utan
                  kolumnkoppling.
                </div>

                <div
                  v-if="getAvailableColumnsForCustomFields().length === 0 && !showAddCustomField"
                  class="text-sm text-t-muted"
                >
                  Alla kolumner är redan mappade. Du behöver rensa några mappningar för att lägga
                  till anpassade fält.
                </div>
              </div>
            </div>
            <!-- Data Preview -->
            <div class="space-y-4 max-lg:border-t max-lg:border-border pt-6">
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
            <UButton :disabled="!canProceedToValidation" @click="proceedToReview">
              Matcha växtnamn
            </UButton>
          </div>
        </div>
      </UCard>
    </div>
    <!-- Step 3: Review and Manual Selection -->
    <div v-show="currentStep === 3 && !stepLoading" class="space-y-6">
      <UCard>
        <template #header>
          <h2 class="text-xl font-semibold">Steg 3: Granska och välj växter</h2>
          <p class="text-t-toned">Kontrollera den automatiska matchningen</p>

          <!-- Automatic Matching Progress -->
          <div v-if="autoMatchingProgress.isRunning" class="mt-4 p-4 bg-info-bg rounded-lg">
            <div class="flex items-center gap-2 text-sm text-info mb-3">
              <UIcon name="i-heroicons-arrow-path" class="animate-spin" />
              <span>
                Matchar växter automatiskt... ({{ autoMatchingProgress.plantsProcessed }}/{{
                  autoMatchingProgress.totalPlants
                }})
              </span>
            </div>

            <!-- Progress bar -->
            <div class="w-full bg-bg-elevated rounded-full h-2 mb-2">
              <div
                class="bg-info h-2 rounded-full transition-all duration-300 ease-out"
                :style="{
                  width:
                    autoMatchingProgress.totalPlants > 0
                      ? `${
                          (autoMatchingProgress.plantsProcessed /
                            autoMatchingProgress.totalPlants) *
                          100
                        }%`
                      : '0%',
                }"
              ></div>
            </div>

            <div v-if="autoMatchingProgress.currentPlant" class="text-xs text-info/80">
              Arbetar på: {{ autoMatchingProgress.currentPlant }}
            </div>
          </div>
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
            class="border border-border rounded-lg p-4 transition-all"
            :class="{
              'border-primary bg-primary-bg': plant.status === 'found',
              'border-secondary bg-secondary-bg': plant.status === 'manual',
              'border-error bg-error-bg':
                plant.status === 'notFound' && plant.suggestions.length > 0,
              'border-warning bg-warning-bg':
                plant.status === 'notFound' &&
                plant.suggestions.length === 0 &&
                plant.hasBeenSearched,
              'border-border bg-bg-elevated text-t-toned': plant.status === 'skip',
              'opacity-75': plant.suggestionsLoading,
            }"
          >
            <div class="flex items-start justify-between max-md:flex-col max-md:gap-4">
              <div class="flex-1 max-md:w-full">
                <h4 class="font-medium" :class="{ 'line-through': plant.status === 'manual' }">
                  {{ plant.original[columnMapping.name] }}
                </h4>
                <!-- Found Match -->
                <div v-if="plant.status === 'found' && plant.facitMatch" class="mn-1">
                  <div class="flex items-center gap-2 flex-wrap">
                    <span class="text-primary font-medium">✓ Hittad: </span>
                    <span>{{ plant.facitMatch.name }}</span>
                    <span v-if="plant.facitMatch.sv_name" class="opacity-60">
                      {{ plant.facitMatch.sv_name }}
                    </span>
                    <!-- Perfect match badge (99.9%+ - truly exact) -->
                    <span
                      v-if="(plant.facitMatch as any).similarity_score >= 0.999"
                      class="inline-flex items-center px-1.5 py-0.5 rounded-full text-xs font-medium bg-primary text-white"
                    >
                      <UIcon name="i-heroicons-check" class="w-3 h-3 mr-1" />
                      Exakt
                    </span>
                    <!-- Near-exact match badge (95-99.8%) -->
                    <span
                      v-else-if="(plant.facitMatch as any).similarity_score >= 0.95"
                      class="inline-flex items-center px-1.5 py-0.5 rounded-full text-xs font-medium bg-secondary/70 text-white"
                    >
                      <UIcon name="i-heroicons-check-circle" class="w-3 h-3 mr-1" />
                      Nästan exakt match
                    </span>
                  </div>
                </div>
                <!-- Manual Selection -->
                <div v-if="plant.status === 'manual' && plant.selectedFacitId" class="mn-1">
                  <span class="text-secondary font-medium">✓ Vald manuellt: </span>
                  <span v-if="plant.selectedPlantData">
                    {{ plant.selectedPlantData.name }}
                    <span v-if="plant.selectedPlantData.sv_name" class="opacity-60 ml-1">
                      {{ plant.selectedPlantData.sv_name }}
                    </span>
                  </span>
                  <span v-else class="text-secondary/80">
                    Växt ID: {{ plant.selectedFacitId }}
                  </span>
                </div>

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
                <div class="text-sm opacity-60 mt-1">
                  <span v-if="plant.selectedPlantData?.serie || plant.facitMatch?.serie">
                    Serie: {{ plant.selectedPlantData?.serie || plant.facitMatch?.serie }}
                  </span>
                  <span v-if="plant.selectedPlantData?.grupp || plant.facitMatch?.grupp">
                    Grupp: {{ plant.selectedPlantData?.grupp || plant.facitMatch?.grupp }}
                  </span>
                  <span v-if="columnMapping.stock && plant.original[columnMapping.stock]">
                    <span
                      v-if="
                        plant.selectedPlantData?.grupp ||
                        plant.facitMatch?.grupp ||
                        plant.selectedPlantData?.serie ||
                        plant.facitMatch?.serie
                      "
                    >
                      | </span
                    >Lager: {{ sanitizeNumericValue(plant.original[columnMapping.stock]) }}
                  </span>
                  <span v-if="columnMapping.price && plant.original[columnMapping.price]">
                    | Pris: {{ sanitizeNumericValue(plant.original[columnMapping.price]) }} kr
                  </span>
                  <span v-if="columnMapping.pot && plant.original[columnMapping.pot]">
                    | Kruka: {{ sanitizeTextValue(plant.original[columnMapping.pot]) }}
                  </span>
                  <span v-if="columnMapping.height && plant.original[columnMapping.height]">
                    | Höjd: {{ sanitizeTextValue(plant.original[columnMapping.height]) }}
                  </span>
                  <span
                    v-if="
                      columnMapping.id_by_plantskola &&
                      plant.original[columnMapping.id_by_plantskola]
                    "
                  >
                    | ID: {{ sanitizeTextValue(plant.original[columnMapping.id_by_plantskola]) }}
                  </span>
                </div>
                <!--  Comment Display -->
                <div
                  v-if="
                    (columnMapping.comment && plant.original[columnMapping.comment]) ||
                    plant.original._editableComment
                  "
                  class="text-sm text-t-toned mt-1 italic"
                >
                  Kommentar:
                  {{
                    columnMapping.comment && plant.original[columnMapping.comment]
                      ? sanitizeTextValue(plant.original[columnMapping.comment])
                      : sanitizeTextValue(plant.original._editableComment)
                  }}
                </div>

                <!-- Private Comment Display -->
                <div
                  v-if="
                    (columnMapping.private_comment &&
                      plant.original[columnMapping.private_comment]) ||
                    plant.original._editablePrivateComment
                  "
                  class="text-sm text-t-toned mt-1 italic"
                >
                  Privat kommentar:
                  {{
                    columnMapping.private_comment && plant.original[columnMapping.private_comment]
                      ? sanitizeTextValue(plant.original[columnMapping.private_comment])
                      : sanitizeTextValue(plant.original._editablePrivateComment)
                  }}
                </div>

                <!-- Custom Fields Display -->
                <div
                  v-if="customFields.length > 0 || plant.original._plantSpecificFields"
                  class="text-sm text-t-toned mt-1"
                >
                  <!-- Global custom fields -->
                  <span v-for="field in customFields" :key="field.key" class="inline-block mr-3">
                    <span v-if="plant.original[field.column]">
                      {{ field.name }}: {{ sanitizeTextValue(plant.original[field.column]) }}
                    </span>
                  </span>
                  <!-- Plant-specific custom fields -->
                  <span
                    v-for="field in plant.original._plantSpecificFields || []"
                    :key="field.key"
                    class="inline-block mr-3"
                  >
                    <span v-if="plant.original[`_${field.key}`]">
                      {{ field.name }}: {{ sanitizeTextValue(plant.original[`_${field.key}`]) }}
                    </span>
                  </span>
                </div>

                <!-- Skip Status -->
                <div v-if="plant.status === 'skip'" class="mt-2 text-sm">
                  <span class="text-t-toned font-medium">⏭ Hoppas över</span>
                </div>
                <!-- Not Found - No matches -->
                <div
                  v-if="
                    plant.status === 'notFound' &&
                    plant.suggestions.length === 0 &&
                    !plant.suggestionsLoading &&
                    !autoMatchingProgress.isRunning
                  "
                  class="mt-2"
                >
                  <div class="text-sm text-warning font-medium">⚠ Ingen matchning hittad</div>
                  <div class="text-xs text-t-toned mt-1">
                    Använd "Sök"-knappen för manuell sökning
                  </div>
                </div>

                <!-- Pending processing during automatic matching -->
                <div
                  v-if="
                    plant.status === 'notFound' &&
                    plant.suggestions.length === 0 &&
                    !plant.suggestionsLoading &&
                    !plant.hasBeenSearched &&
                    autoMatchingProgress.isRunning &&
                    index >= autoMatchingProgress.currentIndex
                  "
                  class="mt-2"
                >
                  <div class="text-sm text-t-muted font-medium">Väntar på bearbetning...</div>
                </div>

                <!-- Suggestions Loading State -->
                <div v-if="plant.suggestionsLoading" class="mt-2">
                  <div class="flex items-center gap-2 text-sm text-t-toned">
                    <UIcon name="i-heroicons-arrow-path" class="animate-spin" />
                    <span>Söker efter liknande växter...</span>
                  </div>
                </div>
                <!-- Suggestions -->
                <div
                  v-if="
                    plant.status === 'notFound' &&
                    (plant.highConfidenceSuggestions.length > 0 ||
                      plant.lowConfidenceSuggestions.length > 0)
                  "
                  class="mt-2"
                >
                  <!-- High confidence matches (always shown) -->
                  <div v-if="plant.highConfidenceSuggestions.length > 0">
                    <p class="text-sm font-medium text-primary mb-2">
                      Bra träffar ({{ plant.highConfidenceSuggestions.length }}):
                    </p>
                    <div class="space-y-1">
                      <div
                        v-for="suggestion in plant.highConfidenceSuggestions"
                        :key="suggestion.id"
                        class="relative"
                      >
                        <!-- High confidence suggestion -->
                        <button
                          v-if="!suggestion.is_synonym"
                          class="block w-full text-left text-sm p-2 rounded border transition-colors border-primary bg-primary/30 hover:bg-primary/40"
                          @click.stop="selectPlantForRow(index, suggestion.id, suggestion)"
                        >
                          <div class="flex justify-between items-center gap-2">
                            <div class="flex-1 min-w-0">
                              <div class="font-medium flex items-center gap-2">
                                {{ suggestion.name }}
                                <!-- Good match indicator (suggestions are < 95% since auto-selection happens at 95%+) -->
                                <span
                                  class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-success text-white"
                                >
                                  Bra match
                                </span>
                              </div>
                              <div v-if="suggestion.sv_name" class="text-xs text-t-toned mt-1">
                                {{ suggestion.sv_name }}
                              </div>
                              <!-- Show if matched synonym -->
                              <div
                                v-if="(suggestion as any).matched_synonym_name"
                                class="text-xs mt-1"
                              >
                                Matchade synonym: "{{ (suggestion as any).matched_synonym_name }}"
                              </div>
                            </div>
                            <!-- Show similarity score -->
                            <div
                              v-if="(suggestion as any).similarity_score !== undefined"
                              class="text-xs flex items-center gap-1 px-2 py-1 rounded bg-primary/30"
                            >
                              {{ Math.round(((suggestion as any).similarity_score || 0) * 100) }}%
                            </div>
                          </div>
                        </button>
                      </div>
                    </div>
                  </div>

                  <!-- Show "visa fler matchningar" button if we have both high and low confidence matches -->
                  <div
                    v-if="
                      plant.highConfidenceSuggestions.length > 0 &&
                      plant.lowConfidenceSuggestions.length > 0 &&
                      !plant.showAllSuggestions
                    "
                    class="mt-3"
                  >
                    <UButton
                      variant="ghost"
                      size="sm"
                      @click="plant.showAllSuggestions = true"
                      class="w-full"
                    >
                      <UIcon name="i-heroicons-chevron-down" class="w-4 h-4 mr-2" />
                      Visa fler matchningar ({{ plant.lowConfidenceSuggestions.length }})
                    </UButton>
                  </div>

                  <!-- Low confidence matches (shown when expanded or when no high confidence matches) -->
                  <div
                    v-if="
                      (plant.showAllSuggestions || plant.highConfidenceSuggestions.length === 0) &&
                      plant.lowConfidenceSuggestions.length > 0
                    "
                    class="mt-3"
                  >
                    <p
                      v-if="plant.highConfidenceSuggestions.length > 0"
                      class="text-sm font-medium text-warning mb-2"
                    >
                      Övriga förslag ({{ plant.lowConfidenceSuggestions.length }}):
                    </p>
                    <p v-else class="text-sm font-medium text-error mb-2">
                      Möjliga träffar ({{ plant.lowConfidenceSuggestions.length }}):
                    </p>
                    <div class="space-y-1">
                      <div
                        v-for="suggestion in plant.lowConfidenceSuggestions"
                        :key="suggestion.id"
                        class="relative"
                      >
                        <!-- Low confidence suggestion -->
                        <button
                          v-if="!suggestion.is_synonym"
                          class="block w-full text-left text-sm p-2 rounded border transition-colors border-error hover:bg-error/10"
                          @click.stop="selectPlantForRow(index, suggestion.id, suggestion)"
                        >
                          <div class="flex justify-between items-center gap-2">
                            <div class="flex-1 min-w-0">
                              <div class="font-medium">
                                {{ suggestion.name }}
                              </div>
                              <div v-if="suggestion.sv_name" class="text-xs text-t-toned mt-1">
                                {{ suggestion.sv_name }}
                              </div>
                              <!-- Show if matched synonym -->
                              <div
                                v-if="(suggestion as any).matched_synonym_name"
                                class="text-xs mt-1"
                              >
                                Matchade synonym: "{{ (suggestion as any).matched_synonym_name }}"
                              </div>
                            </div>
                            <!-- Show similarity score -->
                            <div
                              v-if="(suggestion as any).similarity_score !== undefined"
                              class="text-xs flex items-center gap-1 px-2 py-1 rounded bg-error/10"
                            >
                              {{ Math.round(((suggestion as any).similarity_score || 0) * 100) }}%
                            </div>
                          </div>
                        </button>
                      </div>
                    </div>

                    <!-- Collapse button -->
                    <div v-if="plant.highConfidenceSuggestions.length > 0" class="mt-2">
                      <UButton
                        variant="ghost"
                        size="sm"
                        @click="plant.showAllSuggestions = false"
                        class="w-full"
                      >
                        <UIcon name="i-heroicons-chevron-up" class="w-4 h-4 mr-2" />
                        Dölj övriga förslag
                      </UButton>
                    </div>
                  </div>
                </div>
                <!-- No suggestions after search -->
                <div
                  v-if="
                    plant.status === 'notFound' &&
                    !plant.suggestionsLoading &&
                    plant.suggestions.length === 0 &&
                    plant.hasBeenSearched
                  "
                  class="mt-2"
                >
                  <p class="text-sm text-t-toned">
                    Inga liknande växter hittades. Klicka på "Sök manuellt" för att välja.
                  </p>
                </div>
              </div>
              <!-- Actions -->
              <div class="flex space-x-2 ml-4 max-md:ml-auto">
                <!-- Edit button - available for all plant statuses -->
                <UButton
                  size="sm"
                  variant="solid"
                  color="primary"
                  icon="i-heroicons-pencil-square"
                  @click="openEditPlant(index)"
                  class="flex-shrink-0"
                  v-if="plant.status !== 'skip'"
                >
                  Redigera
                </UButton>

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
                    icon="stash:arrows-switch-solid"
                    @click="openPlantPicker(index)"
                  >
                    Byt växt
                  </UButton>
                  <UButton
                    size="sm"
                    variant="subtle"
                    color="neutral"
                    icon="i-heroicons-arrow-uturn-left"
                    @click="revertPlantRow(index)"
                  >
                    Visa matchningar
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
                    icon="stash:arrows-switch-solid"
                    @click="openPlantPicker(index)"
                  >
                    Byt växt
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
          <div class="flex gap-2">
            <UButton variant="outline" :disabled="importing" @click="goToStep(2)">
              Tillbaka
            </UButton>

            <UButton
              v-if="!autoMatchingProgress.isRunning"
              variant="outline"
              icon="i-heroicons-arrow-path"
              :disabled="importing"
              @click="startAutomaticMatching"
            >
              Starta om matchning
            </UButton>
          </div>

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
    <!-- Step 4: Import Results -->
    <div v-show="currentStep === 4" class="space-y-6">
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
              <UButton to="/plantskola-admin/lager"> Visa lager </UButton>

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
          </div>
          <PlantPicker
            :edit-value="0"
            :current-plant-i-d="0"
            @select="onPlantSelected"
            @add-select="onPlantSelected"
          />
        </div>
      </template>
    </UModal>

    <!-- Plant Edit Modal -->
    <UModal v-model:open="editPlantModal" class="p-8">
      <template #content>
        <div class="flex items-center justify-between w-full mb-4">
          <h3 class="text-lg font-semibold">Redigera växt</h3>
          <UButton
            color="neutral"
            variant="ghost"
            icon="i-heroicons-x-mark-20-solid"
            @click="cancelEditPlant"
          />
        </div>

        <div v-if="editingPlant.index !== null && editingPlant.data" class="space-y-4">
          <!-- Show which plant is being edited -->
          <div class="border-2 border-secondary p-3 rounded-lg">
            <p class="font-medium" v-if="validatedPlants[editingPlant.index]?.selectedPlantData">
              {{ validatedPlants[editingPlant.index]?.selectedPlantData?.name }}
            </p>
            <p class="font-medium" v-else>
              {{ validatedPlants[editingPlant.index]?.original[columnMapping.name] }}
            </p>
          </div>

          <!-- Edit form -->
          <div class="space-y-4 max-h-[60vh] overflow-y-auto">
            <!-- Basic fields in a grid -->
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <!-- Stock -->
              <div v-if="columnMapping.stock">
                <label class="block text-sm font-medium mb-1">Lager</label>
                <UInput
                  v-model="editingPlant.data.stock"
                  type="number"
                  placeholder="Antal i lager"
                  min="0"
                />
              </div>

              <!-- Price -->
              <div v-if="columnMapping.price">
                <label class="block text-sm font-medium mb-1">Pris (kr)</label>
                <UInput
                  v-model="editingPlant.data.price"
                  type="number"
                  placeholder="Pris i kronor"
                  min="0"
                  step="1"
                />
              </div>

              <!-- Pot -->
              <div v-if="columnMapping.pot">
                <label class="block text-sm font-medium mb-1">Kruka</label>
                <UInput v-model="editingPlant.data.pot" placeholder="T.ex. C5, P9" />
              </div>

              <!-- Height -->
              <div v-if="columnMapping.height">
                <label class="block text-sm font-medium mb-1">Höjd</label>
                <UInput v-model="editingPlant.data.height" placeholder="T.ex. 120-140" />
              </div>

              <!-- ID by plantskola -->
              <div v-if="columnMapping.id_by_plantskola" class="md:col-span-2">
                <label class="block text-sm font-medium mb-1">Eget ID/Artikelnummer</label>
                <UInput
                  v-model="editingPlant.data.id_by_plantskola"
                  placeholder="Ditt interna ID eller artikelnummer"
                />
              </div>
            </div>
            <!-- Comments - Always shown, even if no column is mapped -->
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <!-- Public comment -->
              <div>
                <label class="block text-sm font-medium mb-1">Kommentar (visas för kunder)</label>
                <UTextarea
                  v-model="editingPlant.data.comment"
                  placeholder="Beskrivning som visas för kunder"
                  :rows="2"
                />
              </div>

              <!-- Private comment -->
              <div>
                <label class="block text-sm font-medium mb-1"
                  >Privat kommentar (endast för dig)</label
                >
                <UTextarea
                  v-model="editingPlant.data.private_comment"
                  placeholder="Intern anteckning som bara du ser"
                  :rows="2"
                />
              </div>
            </div>

            <!-- Custom fields from global configuration -->
            <div class="pt-4">
              <h4 class="font-semibold mb-2 flex items-center gap-2">
                Anpassade fält
                <UButton
                  size="xs"
                  variant="outline"
                  icon="i-heroicons-plus"
                  @click="showAddCustomFieldInEdit = true"
                >
                  Lägg till
                </UButton>
              </h4>

              <!-- Add custom field form in edit modal -->
              <div
                v-if="showAddCustomFieldInEdit"
                class="mb-4 p-3 rounded-lg bg-bg-elevated border border-border space-y-3"
              >
                <h5 class="font-medium">Nytt anpassat fält</h5>
                <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
                  <div>
                    <label class="block text-sm font-medium mb-1">Fältnamn:</label>
                    <UInput
                      v-model="newCustomFieldInEdit.name"
                      placeholder="t.ex. 'Ålder', 'Ursprung'"
                      class="w-full"
                    />
                  </div>
                  <div>
                    <label class="block text-sm font-medium mb-1">Kolumn (valfritt):</label>
                    <USelect
                      v-model="newCustomFieldInEdit.column"
                      :items="
                        getAvailableColumnsForCustomFields().map((h) => ({ value: h, label: h }))
                      "
                      placeholder="Välj kolumn eller lämna tom"
                      class="w-full"
                      @change="onColumnChangeInEdit"
                    />
                  </div>
                </div>
                <div>
                  <label class="block text-sm font-medium mb-1">Värde:</label>
                  <UInput
                    v-model="newCustomFieldInEdit.value"
                    placeholder="Värde för detta fält"
                    class="w-full"
                  />
                </div>
                <!-- "For all plants" checkbox - only show when column is selected -->
                <div v-if="newCustomFieldInEdit.column" class="flex items-center gap-2">
                  <UCheckbox v-model="newCustomFieldInEdit.forAll" />
                  <span class="text-sm">Lägg till för alla växter</span>
                </div>
                <div class="flex gap-2">
                  <UButton
                    size="sm"
                    :disabled="
                      !newCustomFieldInEdit.name.trim() ||
                      (newCustomFieldInEdit.forAll && !newCustomFieldInEdit.column)
                    "
                    @click="addCustomFieldToEditPlant"
                  >
                    Lägg till
                  </UButton>
                  <UButton
                    variant="outline"
                    size="sm"
                    @click="
                      showAddCustomFieldInEdit = false;
                      newCustomFieldInEdit = { name: '', column: '', value: '', forAll: false };
                    "
                  >
                    Avbryt
                  </UButton>
                </div>
              </div>

              <!-- Custom fields display section -->
              <div
                v-if="
                  customFields.length > 0 ||
                  (editingPlant.data?.plantSpecificFields &&
                    editingPlant.data.plantSpecificFields.length > 0)
                "
                class=""
              >
                <!-- Global custom fields -->
                <div v-for="field in customFields" :key="field.key" class="flex flex-col mb-3">
                  <div class="flex items-center gap-2 text-sm font-medium mb-1">
                    <!-- Edit field name inline -->
                    <div
                      v-if="editingFieldName.isEditing && editingFieldName.fieldKey === field.key"
                      class="flex items-center gap-1 flex-1"
                    >
                      <UInput
                        v-model="editingFieldName.newName"
                        class="text-sm"
                        size="sm"
                        autofocus
                        @keyup.enter="saveFieldNameEdit"
                        @keyup.escape="cancelEditingFieldName"
                      />
                      <UButton size="xs" icon="i-heroicons-check" @click="saveFieldNameEdit" />
                      <UButton
                        size="xs"
                        variant="ghost"
                        icon="i-heroicons-x-mark"
                        @click="cancelEditingFieldName"
                      />
                    </div>
                    <!-- Normal field name display -->
                    <template v-else>
                      <span class="flex-1">{{ field.name }}</span>
                      <span class="text-xs text-t-toned px-1 py-0.5 rounded bg-bg-elevated"
                        >Alla växter</span
                      >
                      <UButton
                        size="xs"
                        variant="ghost"
                        icon="i-heroicons-pencil"
                        class="text-primary"
                        @click="startEditingFieldName(field, true)"
                      />
                      <UButton
                        size="xs"
                        variant="ghost"
                        icon="i-heroicons-trash"
                        class="text-error"
                        @click="openDeleteCustomFieldModal(-1, field)"
                      />
                    </template>
                  </div>
                  <UInput
                    v-model="editingPlant.data[field.key]"
                    :placeholder="`Värde för ${field.name}`"
                  />
                </div>

                <!-- Plant-specific custom fields -->
                <div
                  v-for="(field, idx) in editingPlant.data?.plantSpecificFields"
                  :key="field.key"
                  class="relative"
                >
                  <div class="flex items-center gap-2 text-sm font-medium mb-1">
                    <!-- Edit field name inline -->
                    <div
                      v-if="editingFieldName.isEditing && editingFieldName.fieldKey === field.key"
                      class="flex items-center gap-1 flex-1"
                    >
                      <UInput
                        v-model="editingFieldName.newName"
                        class="text-sm"
                        size="sm"
                        autofocus
                        @keyup.enter="saveFieldNameEdit"
                        @keyup.escape="cancelEditingFieldName"
                      />
                      <UButton size="xs" icon="i-heroicons-check" @click="saveFieldNameEdit" />
                      <UButton
                        size="xs"
                        variant="ghost"
                        icon="i-heroicons-x-mark"
                        @click="cancelEditingFieldName"
                      />
                    </div>
                    <!-- Normal field name display -->
                    <template v-else>
                      <span class="flex-1">{{ field.name }}</span>
                      <span class="text-xs text-t-toned px-1 py-0.5 rounded bg-bg-elevated"
                        >Endast denna växt</span
                      >
                      <UButton
                        size="xs"
                        variant="ghost"
                        icon="i-heroicons-pencil"
                        class="text-primary"
                        @click="startEditingFieldName(field, false, idx)"
                      />
                      <UButton
                        size="xs"
                        variant="ghost"
                        icon="i-heroicons-trash"
                        class="text-error"
                        @click="openDeleteCustomFieldModal(idx, field)"
                      />
                    </template>
                  </div>
                  <UInput
                    class="w-full"
                    :ui="{ root: 'w-full', base: 'w-full' }"
                    v-model="editingPlant.data[field.key]"
                    :placeholder="`Värde för ${field.name}`"
                  />
                </div>
              </div>

              <!-- Show message when no custom fields exist -->
              <div
                v-if="
                  customFields.length === 0 &&
                  (!editingPlant.data?.plantSpecificFields ||
                    editingPlant.data.plantSpecificFields.length === 0) &&
                  !showAddCustomFieldInEdit
                "
                class="text-sm text-t-muted mt-2"
              >
                Inga anpassade fält har lagts till än.
              </div>
            </div>
          </div>

          <!-- Actions -->
          <div class="flex justify-end space-x-3 pt-4 border-t border-border">
            <UButton variant="outline" @click="cancelEditPlant"> Avbryt </UButton>
            <UButton @click="saveEditedPlant" icon="i-heroicons-check"> Spara ändringar </UButton>
          </div>
        </div>
      </template>
    </UModal>

    <!-- Delete Custom Field Confirmation Modal -->
    <UModal v-model:open="deleteCustomFieldModal.open" class="p-8">
      <template #content>
        <div class="">
          <h3 class="text-lg font-semibold">Ta bort anpassat fält</h3>
          <p class="text-t-muted">
            Vill du ta bort fältet "{{ deleteCustomFieldModal.field?.name }}"?
          </p>
          <p v-if="deleteCustomFieldModal.editIndex === -1" class="text-t-muted">
            Om du vill ta bort från endast denna växt, lämna fältet blankt.
          </p>
          <div class="flex gap-2 justify-end mt-4">
            <UButton variant="outline" @click="deleteCustomFieldModal.open = false">Avbryt</UButton>

            <!-- For global fields (editIndex === -1) -->
            <UButton
              v-if="deleteCustomFieldModal.editIndex === -1"
              color="error"
              @click="deleteCustomFieldForAll"
            >
              Ta bort från alla växter
            </UButton>

            <!-- For plant-specific fields (editIndex >= 0) -->
            <template v-else>
              <!-- Show option to delete from all plants if this is also a global field -->
              <UButton
                v-if="customFields.some((f) => f.key === deleteCustomFieldModal.field?.key)"
                color="error"
                @click="deleteCustomFieldForAll"
              >
                Ta bort från alla växter
              </UButton>
              <!-- Always show option to delete just from this plant -->
              <UButton color="warning" @click="deleteCustomFieldForThisPlant">
                Ta bort endast för denna växt
              </UButton>
            </template>
          </div>
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
