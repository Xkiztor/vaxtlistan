<script setup lang="ts">
// InlineSearch component for navbar/hero
// Updated to use high-performance server-side search instead of loading all data into memory
import type { Facit } from '~/types/supabase-tables';

// Props: mode controls size/layout
const props = defineProps<{ mode?: 'navbar' | 'hero' | 'dropdown' }>();

const { width, height } = useWindowSize();
const expandSearchScreenWidth = 550; // Width at which search expands

const emit = defineEmits(['select', 'deslect']);
const isFocused = ref(false);

const supabase = useSupabaseClient();
const router = useRouter();
const { searchPlants, getSearchSuggestions } = useSearch();

const search = ref('');
const results = ref<Facit[]>([]);
const loading = ref(false);
const showDropdown = ref(false);
const minChars = 2; // Reduced from 3 for better UX
const maxResults = 5;
const inputRef = ref<HTMLInputElement | null>(null);

// Debounced search to avoid too many API calls
const debouncedSearch = useDebounceFn(async () => {
  if (search.value.length < minChars) {
    results.value = [];
    showDropdown.value = false;
    return;
  }

  loading.value = true;
  try {
    const searchResult = await searchPlants(search.value, {
      limit: maxResults,
      threshold: 0.2, // Lower threshold for more fuzzy results
    });

    results.value = searchResult.results;
    showDropdown.value = results.value.length > 0;
  } catch (error) {
    console.error('Search error:', error);
    results.value = [];
    showDropdown.value = false;
  } finally {
    loading.value = false;
  }
}, 300);

// Watch search input and trigger debounced search
watch(
  () => search.value,
  (val) => {
    if (val.length >= minChars) {
      debouncedSearch();
    } else {
      results.value = [];
      showDropdown.value = false;
    }
  }
);

// Handle navigation to all results page
function goToAllResults() {
  showDropdown.value = false;
  router.push({ path: '/vaxt/s', query: { q: search.value } });
}

// Handle Enter key
function onEnter(e: KeyboardEvent) {
  if (search.value.length >= minChars) {
    goToAllResults();
  }
}

// Handle click outside to close dropdown
function onBlurDropdown(e: FocusEvent) {
  // Small delay to allow for clicking on dropdown items
  setTimeout(() => {
    showDropdown.value = false;
  }, 120);
}

// Focus input when hero mode
onMounted(() => {
  if (props.mode === 'hero' && inputRef.value) {
    inputRef.value.focus();
  }
});

function handleFocus() {
  isFocused.value = true;
  emit('select');
  if (search.value.length >= minChars && results.value.length > 0) showDropdown.value = true;
}

function handleBlur(e: FocusEvent) {
  isFocused.value = false;
  emit('deslect');
  onBlurDropdown(e);
}

function clearSearch() {
  search.value = '';
  results.value = [];
  showDropdown.value = false;
}

const deSelect = () => {
  isFocused.value = false;
  emit('deslect');
  showDropdown.value = false;
  // Try to blur the input in a robust way
  let el = inputRef.value;
  if (el) {
    if (typeof el.blur === 'function') {
      el.blur();
    } else if ('input' in el && typeof (el as any).input?.blur === 'function') {
      (el as any).input.blur();
    } else if ('$el' in el && typeof (el as any).$el?.querySelector === 'function') {
      (el as any).$el.querySelector('input')?.blur();
    }
  }
};
</script>

<template>
  <div
    class="relative grow"
    :class="
      props.mode === 'hero'
        ? 'max-w-2xl mx-auto'
        : width < expandSearchScreenWidth
        ? 'w-full'
        : 'max-w-xs'
    "
  >
    <UInput
      ref="inputRef"
      v-model="search"
      :placeholder="
        props.mode === 'hero'
          ? 'Sök växtnamn'
          : width <= expandSearchScreenWidth
          ? 'Sök'
          : 'Sök växt'
      "
      :size="width > expandSearchScreenWidth ? 'xl' : 'lg'"
      class="w-full"
      leading-icon="i-material-symbols-search-rounded"
      loading-icon="ant-design:loading-outlined"
      :loading="loading"
      @keydown.enter="onEnter"
      @focus="handleFocus"
      @blur="handleBlur"
      :ui="{
        leadingIcon: 'pointer-events-none',
        leading: 'pointer-events-none',
      }"
      autocomplete="off"
    >
      <template #trailing>
        <UButton
          v-if="search.length > 0"
          color="neutral"
          variant="ghost"
          size="xs"
          icon="i-material-symbols-close-rounded"
          @mousedown.prevent="clearSearch"
          class="!p-1"
          aria-label="Rensa sökfält"
        />
      </template>
    </UInput>

    <!-- Dropdown with results -->
    <transition name="fade">
      <div
        v-if="showDropdown && results.length > 0"
        class="absolute left-0 right-0 z-50 bg-bg-elevated border-1 border-border rounded-lg shadow-lg mt-2 overflow-hidden"
      >
        <ul>
          <li
            v-for="plant in results"
            :key="plant.id"
            class="hover:bg-bg-accented cursor-pointer px-4 py-3 flex flex-col gap-1 border-b-1 border-border last:border-b-0"
            @mousedown.prevent="
              router.push({
                path: `/vaxt/${plant.id}/${plant.name
                  .toLowerCase()
                  .replace(/[^a-z0-9åäö\- ]/gi, '')
                  .replace(/\s+/g, '+')
                  .replace(/-+/g, '+')
                  .replace(/^-+|-+$/g, '')}`,
              }),
                deSelect()
            "
          >
            <span class="font-semibold">{{ plant.name }}</span>
            <span v-if="plant.sv_name" class="text-t-muted text-sm">{{ plant.sv_name }}</span>
            <div class="flex gap-2 mt-1 max-md:hidden">
              <UBadge v-if="plant.plant_type" color="primary" variant="soft">{{
                plant.plant_type
              }}</UBadge>
            </div>
          </li>
        </ul>
        <UButton
          class="w-full rounded-none border-t-1 border-border font-bold underline text-secondary"
          size="xl"
          color="none"
          @mousedown.prevent="goToAllResults"
        >
          Visa alla resultat...
        </UButton>
      </div>
    </transition>
  </div>
</template>

<style scoped>
.fade-enter-active,
.fade-leave-active {
  transition: all 0.2s ease-in-out;
}
.fade-enter-from,
.fade-leave-to {
  opacity: 0;
  transform: translateY(-250px);
}
</style>
