<!-- Simple test component to debug fuzzy search -->
<template>
  <div class="p-6 max-w-4xl mx-auto">
    <h1 class="text-2xl font-bold mb-6">Fuzzy Search Debug</h1>
    <!-- Test search -->
    <UFormGroup label="Test Search" class="mb-4">
      <UInput
        v-model="testQuery"
        placeholder="Enter plant name to test..."
        @keyup.enter="runTest"
      />
      <div class="flex gap-2 mt-2">
        <UButton @click="runTest" :loading="testing">Test Search</UButton>
        <UButton @click="testSynonyms" :loading="testing" color="primary">Test Synonyms</UButton>
        <UButton @click="testCommonNames" :loading="testing" color="success"
          >Test Common Names</UButton
        >
        <UButton @click="testFallback" :loading="testing" color="warning">Test Fallback</UButton>
        <UButton @click="testMultiWord" :loading="testing" color="primary">Test Multi-Word</UButton>
        <UButton @click="testCultivarNames" :loading="testing" color="secondary"
          >Test Cultivar Names</UButton
        >
      </div>
    </UFormGroup>
    <!-- Database candidates -->
    <div v-if="dbCandidates.length > 0" class="mb-6">
      <h3 class="text-lg font-semibold mb-2">
        Database Candidates ({{ dbCandidates.length }})
        <span v-if="searchMethodInfo" class="text-sm font-normal text-blue-600 ml-2">
          {{ searchMethodInfo }}
        </span>
      </h3>
      <div class="bg-gray-50 p-4 rounded max-h-60 overflow-y-auto">
        <div
          v-for="(candidate, index) in dbCandidates.slice(0, 10)"
          :key="index"
          class="mb-2 text-sm"
        >
          <strong>{{ candidate.name }}</strong>
          <span v-if="candidate.sv_name" class="text-gray-600"> ({{ candidate.sv_name }})</span>
          <div class="text-xs text-gray-500">
            ID: {{ candidate.id }}, DB Score: {{ candidate.similarity_score }}, Type:
            {{ candidate.plant_type }}
            <span
              v-if="candidate.match_details"
              class="ml-2 px-1 py-0.5 bg-blue-100 text-blue-700 rounded text-xs"
            >
              {{
                candidate.match_details === 'fast_match'
                  ? 'Fast'
                  : candidate.match_details === 'multi_word_match'
                  ? 'Multi-word'
                  : candidate.match_details === 'fallback_match'
                  ? 'Fallback'
                  : 'Standard'
              }}
            </span>
          </div>
          <div v-if="candidate.has_synonyms" class="text-xs text-blue-600 mt-1">
            Synonyms: {{ candidate.has_synonyms }}
          </div>
        </div>
        <div v-if="dbCandidates.length > 10" class="text-xs text-gray-500 mt-2">
          ... and {{ dbCandidates.length - 10 }} more
        </div>
      </div>
    </div>
    <!-- Fuzzy results -->
    <div v-if="fuzzyResults.length > 0" class="mb-6">
      <h3 class="text-lg font-semibold mb-2">Fuzzy Results ({{ fuzzyResults.length }})</h3>
      <div class="space-y-2">
        <div v-for="result in fuzzyResults" :key="result.id" class="bg-white border rounded p-3">
          <div class="flex justify-between items-start">
            <div>
              <strong>{{ result.name }}</strong>
              <!-- Visual indicators for prioritization -->
              <span
                v-if="result.name?.includes(`'`)"
                class="ml-2 px-1 py-0.5 bg-purple-100 text-purple-700 rounded text-xs"
              >
                🌸 Cultivar
              </span>
              <span
                v-if="hasCapsWords(result.name)"
                class="ml-2 px-1 py-0.5 bg-blue-100 text-blue-700 rounded text-xs"
              >
                🔤 CAPS
              </span>
              <span v-if="result.sv_name" class="text-gray-600 ml-2">({{ result.sv_name }})</span>
              <div class="text-sm text-gray-500 mt-1">
                Match Type: {{ result.match_type }} | Matched Text: "{{ result.matched_text }}"
              </div>
              <!-- Show synonym info if matched via synonym -->
              <div v-if="result.match_type === 'synonym'" class="text-xs text-blue-600 mt-1">
                Found via synonym: "{{ result.matched_text }}"
              </div>
              <!-- Show all synonyms for context -->
              <div v-if="result.has_synonyms" class="text-xs text-gray-400 mt-1">
                All synonyms: {{ result.has_synonyms }}
              </div>
            </div>
            <div class="text-right">
              <UBadge
                :color="
                  result.similarity_score > 0.8
                    ? 'success'
                    : result.similarity_score > 0.6
                    ? 'primary'
                    : 'warning'
                "
                variant="soft"
              >
                {{ Math.round(result.similarity_score * 100) }}%
              </UBadge>
              <div class="text-xs text-gray-500 mt-1">
                {{ result.suggested_reason }}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Manual similarity test -->
    <div class="mb-6">
      <h3 class="text-lg font-semibold mb-2">Manual Similarity Test</h3>
      <div class="grid grid-cols-2 gap-4">
        <UFormGroup label="String 1">
          <UInput v-model="str1" placeholder="First string" />
        </UFormGroup>
        <UFormGroup label="String 2">
          <UInput v-model="str2" placeholder="Second string" />
        </UFormGroup>
      </div>
      <UButton @click="testSimilarity" class="mt-2">Test Similarity</UButton>
      <div v-if="manualScore !== null" class="mt-2 text-lg">
        Similarity Score: <strong>{{ manualScore }}</strong>
      </div>
    </div>

    <!-- Error display -->
    <div v-if="error" class="bg-red-50 border border-red-200 rounded p-4 text-red-800">
      <strong>Error:</strong> {{ error }}
    </div>

    <!-- Debug info -->
    <details class="mt-6">
      <summary class="cursor-pointer font-semibold">Debug Info</summary>
      <pre class="bg-gray-100 p-4 rounded mt-2 text-xs overflow-auto">{{ debugInfo }}</pre>
    </details>
  </div>
</template>

<script setup lang="ts">
// Debug component for fuzzy search

const { searchPlantsFuzzy } = usePlantFuzzySearch();
const { fuzzyMatch, quickSimilarity } = useFuzzyMatch();
const supabase = useSupabaseClient();

// Helper function to check for caps words
const hasCapsWords = (name: string | undefined) => {
  if (!name) return false;
  return /\b[A-Z]{2,}\b/.test(name);
};

// Test state
const testQuery = ref('pinus');
const testing = ref(false);
const error = ref('');

// Results
const dbCandidates = ref<any[]>([]);
const fuzzyResults = ref<any[]>([]);
const searchMethodInfo = ref<string>('');

// Manual similarity test
const str1 = ref('pinus');
const str2 = ref('pinus sylvestris');
const manualScore = ref<number | null>(null);

// Debug info
const debugInfo = ref<any>({});

const runTest = async () => {
  if (!testQuery.value.trim()) return;

  testing.value = true;
  error.value = '';
  dbCandidates.value = [];
  fuzzyResults.value = [];

  try {
    console.log('Starting test for:', testQuery.value); // Step 1: Get raw database candidates
    const { data: candidates, error: dbError } = await (supabase as any).rpc(
      'search_plants_fuzzy_match',
      {
        p_search_term: testQuery.value,
        p_result_limit: 50,
        p_minimum_similarity: 0.0,
      }
    );

    if (dbError) {
      throw new Error(`Database error: ${dbError.message}`);
    }
    console.log('Database returned:', candidates);
    dbCandidates.value = candidates || []; // Analyze search method used
    if (candidates && candidates.length > 0) {
      const hasFallbackResults = candidates.some((c: any) => c.match_details === 'fallback_match');
      const hasFastResults = candidates.some((c: any) => c.match_details === 'fast_match');
      const hasMultiWordResults = candidates.some(
        (c: any) => c.match_details === 'multi_word_match'
      );

      if (hasFastResults && !hasFallbackResults && !hasMultiWordResults) {
        searchMethodInfo.value = '⚡ Fast Search (Exact/prefix matches found)';
      } else if (hasMultiWordResults && !hasFallbackResults) {
        searchMethodInfo.value = '� Multi-word Search (Word-based matching)';
      } else if (hasFallbackResults && !hasMultiWordResults) {
        searchMethodInfo.value = '�🔍 Fallback Search (No exact matches found)';
      } else if (hasFastResults && hasMultiWordResults) {
        searchMethodInfo.value = '🔄 Mixed Results (Fast + Multi-word)';
      } else if (hasMultiWordResults && hasFallbackResults) {
        searchMethodInfo.value = '🔄 Mixed Results (Multi-word + Fallback)';
      } else if (hasFastResults && hasFallbackResults) {
        searchMethodInfo.value = '🔄 Mixed Results (Fast + Fallback)';
      } else {
        searchMethodInfo.value = '📊 Standard Search';
      }
    }

    if (!candidates || candidates.length === 0) {
      error.value = 'No candidates returned from database';
      searchMethodInfo.value = '❌ No Results';
      return;
    }

    // Step 2: Apply fuzzy matching
    console.log('Applying fuzzy matching...');
    const results = fuzzyMatch(testQuery.value, candidates, {
      threshold: 0.2, // Lower threshold for testing
      maxResults: 10,
      includeSwedishNames: true,
      includeSynonyms: true,
    });

    console.log('Fuzzy results:', results);
    fuzzyResults.value = results;

    // Update debug info
    debugInfo.value = {
      searchTerm: testQuery.value,
      dbCandidatesCount: candidates.length,
      fuzzyResultsCount: results.length,
      firstCandidate: candidates[0],
      firstResult: results[0],
      timestamp: new Date().toISOString(),
    };
  } catch (err: any) {
    console.error('Test error:', err);
    error.value = err.message || 'Unknown error';
  } finally {
    testing.value = false;
  }
};

const testSimilarity = () => {
  if (!str1.value || !str2.value) return;
  manualScore.value = quickSimilarity(str1.value, str2.value);
  console.log('Manual similarity test:', {
    str1: str1.value,
    str2: str2.value,
    score: manualScore.value,
  });
};

// Test synonyms specifically
const testSynonyms = async () => {
  // Test with terms that should match synonyms
  const synonymTests = ['tall', 'dwarf', 'compact', 'weeping'];
  testQuery.value = synonymTests[Math.floor(Math.random() * synonymTests.length)];
  await runTest();
};

// Test common names
const testCommonNames = async () => {
  // Test with Swedish/common names
  const commonNameTests = ['gran', 'tall', 'björk', 'ask', 'ek'];
  testQuery.value = commonNameTests[Math.floor(Math.random() * commonNameTests.length)];
  await runTest();
};

// Test fallback functionality with difficult search terms
const testFallback = async () => {
  // Test with terms that should trigger fallback search - mix of short terms and partial matches
  const fallbackTests = [
    'pin',
    'ac',
    'ros',
    'ab',
    'que',
    'syl',
    'alb',
    'rub',
    'pur',
    'gla',
    'pinu',
    'acer',
    'quer',
    'betu',
    'gran',
    'tall',
    'ask',
  ];
  testQuery.value = fallbackTests[Math.floor(Math.random() * fallbackTests.length)];
  await runTest();
};

// Test multi-word search functionality
const testMultiWord = async () => {
  // Test with multi-word terms that should trigger multi-word search
  const multiWordTests = [
    'Actinidia kolomikta Anna',
    'Pinus sylvestris Watereri',
    'Acer palmatum Atropurpureum',
    'Rosa rugosa Alba',
    'Betula pendula Youngii',
    'Quercus robur Fastigiata',
  ];
  testQuery.value = multiWordTests[Math.floor(Math.random() * multiWordTests.length)];
  await runTest();
};

// Test cultivar/sort name prioritization
const testCultivarNames = async () => {
  // Test with cultivar names (sort names in quotes) to verify prioritization
  const cultivarTests = [
    'Anna', // Should prioritize Actinidia kolomikta 'Anna'
    'Watereri', // Should prioritize Pinus sylvestris 'Watereri'
    'Youngii', // Should prioritize Betula pendula 'Youngii'
    'Fastigiata', // Should prioritize Quercus robur 'Fastigiata'
    'Alba', // Should prioritize varieties with 'Alba' in quotes
    'Aurea', // Should prioritize varieties with 'Aurea' in quotes
    'Glauca', // Should prioritize varieties with 'Glauca' in quotes
    'Pendula', // Should prioritize varieties with 'Pendula' in quotes
  ];
  testQuery.value = cultivarTests[Math.floor(Math.random() * cultivarTests.length)];
  await runTest();
};

// Auto-run test on mount
onMounted(() => {
  runTest();
});
</script>
