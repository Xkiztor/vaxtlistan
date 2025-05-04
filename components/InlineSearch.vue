<script setup lang="ts">
// InlineSearch component for navbar/hero
// Uses Fuse.js and Pinia store for fast fuzzy search
import Fuse from 'fuse.js';
import type { FacitFuse } from '~/types/supabase-tables';
import { useFacitStore } from '~/stores/facit';

// Props: mode controls size/layout
const props = defineProps<{ mode?: 'navbar' | 'hero' | 'dropdown' }>();

const { width, height } = useWindowSize();
const expandSearchScreenWidth = 550; // Width at which search expands

const emit = defineEmits(['select', 'deslect']);
const isFocused = ref(false);

const supabase = useSupabaseClient();
const router = useRouter();
const facitStore = useFacitStore();

const search = ref('');
const results = ref<FacitFuse[]>([]);
const loading = ref(false);
const showDropdown = ref(false);
const minChars = 3;
const maxResults = 5;
const inputRef = ref<HTMLInputElement | null>(null);

// Fetch all plants if not already loaded
async function ensureFacitLoaded() {
  loading.value = true;
  try {
    await facitStore.fetchFacit(supabase);
  } catch (e) {
    // Optionally handle error
  } finally {
    loading.value = false;
  }
}

// Perform fuzzy search using Fuse.js
async function performSearch() {
  await ensureFacitLoaded();
  if (search.value.length < minChars) {
    results.value = [];
    showDropdown.value = false;
    return;
  }
  const fuse = new Fuse(facitStore.facit || [], {
    keys: ['name', 'sv_name'],
    threshold: 0.4,
    includeScore: true,
    ignoreLocation: true,
    includeMatches: true,
  });
  const fuseResults = fuse.search(search.value);
  // results.value = fuseResults.slice(0, maxResults).filter((item) => item.score! < 0.45);
  results.value = fuseResults
    .slice(0, maxResults)
    .map((item) => {
      if (item.matches && item.matches[0]?.key === 'sv_name' && typeof item.score === 'number') {
        return { ...item, score: item.score * 10 };
      }
      return item;
    })
    .sort((a, b) => (a.score ?? 0) - (b.score ?? 0));

  showDropdown.value = results.value.length > 0;
}

// Watch search input and trigger search
watch(
  () => search.value,
  (val) => {
    if (val.length >= minChars) {
      performSearch();
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
  setTimeout(() => {
    showDropdown.value = false;
  }, 120); // Delay to allow click on dropdown
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
  // Try to blur the input in a robust way
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
        class="absolute left-0 right-0 z-50 bg-elevated border-1 border-regular rounded-lg shadow-lg mt-2 overflow-hidden"
      >
        <ul>
          <li
            v-for="plant in results"
            :key="plant.item.id"
            class="hover:bg-accented cursor-pointer px-4 py-3 flex flex-col gap-1 border-b-1 border-regular last:border-b-0"
            @mousedown.prevent="
              router.push({
                path: `/vaxt/${plant.item.id}/${plant.item.name
                  .toLowerCase()
                  .replace(/[^a-z0-9åäö\- ]/gi, '')
                  .replace(/\s+/g, '+')
                  .replace(/-+/g, '+')
                  .replace(/^-+|-+$/g, '')}`,
              }),
                deSelect()
            "
          >
            <span class="font-semibold">{{ plant.item.name }}</span>
            <span v-if="plant.item.sv_name" class="text-muted text-sm">{{
              plant.item.sv_name
            }}</span>
            <div class="flex gap-2 mt-1 max-md:hidden">
              <UBadge v-if="plant.item.type" color="primary" variant="soft">{{
                plant.item.type
              }}</UBadge>
              <UBadge v-if="plant.item.edible" color="primary" variant="soft">Ätlig</UBadge>
              <UBadge v-if="plant.item.zone" color="neutral" variant="soft"
                >Zon {{ plant.item.zone }}</UBadge
              >
              <!-- <UBadge color="neutral" variant="soft">{{ plant.score }}</UBadge>
              <UBadge color="neutral" variant="soft">Nr: {{ plant.refIndex }}</UBadge>
              <UBadge color="neutral" variant="soft">{{ plant.matches }}</UBadge> -->
            </div>
          </li>
        </ul>
        <UButton
          class="w-full rounded-none border-t-1 border-regular font-bold underline text-secondary"
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
