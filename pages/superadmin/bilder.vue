<script setup lang="ts">
import type { Facit, GoogleImageResult } from '~/types/supabase-tables';

// Page meta
definePageMeta({
  layout: 'superadmin',
  middleware: 'superadmin',
});

useHead({
  title: 'Bildhantering - Superadmin - Växtlistan',
});

// Filter options
const filterOptions = [
  { label: 'Alla växter med bilder', value: 'all' },
  { label: 'Endast omordnade', value: 'reordered' },
  { label: 'Endast orörda', value: 'not-reordered' },
];

// Reactive state
const selectedFilter = ref('all');
const unsavedChanges = ref(new Set<number>());
const imageLoadErrors = ref(new Map<string, boolean>());

// Add image modal state
const isAddImageModalOpen = ref(false);
const currentPlantForImage = ref<Facit | null>(null);
const newImageUrl = ref('');
const newImageTitle = ref('');
const isAddingImage = ref(false);
const imageAddedSuccess = ref(false);

// Google image search state
const searchQuery = ref('');
const searchResults = ref<any[]>([]);
const isSearching = ref(false);
const searchError = ref('');
const searchHasBeenPerformed = ref(false);
const currentPage = ref(1);
const totalPages = ref(1);

// Integrated image viewer state (within the modal)
const isModalImageViewerOpen = ref(false);
const modalCurrentImages = ref<{ src: string; alt: string }[]>([]);
const modalCurrentImageIndex = ref(0);

// Image viewer state
const isImageViewerOpen = ref(false);
const currentImages = ref<{ src: string; alt: string }[]>([]);
const currentImageIndex = ref(0);

// Supabase client
const supabase = useSupabaseClient();

// Watch for page changes and auto-search if we have already searched
watch(currentPage, (newPage, oldPage) => {
  // Only auto-search if we have a search query and have performed a search before
  if (searchQuery.value.trim() && searchHasBeenPerformed.value && newPage !== oldPage) {
    searchImages(newPage);
  }
});

// Fetch plants with images
const {
  data: plants,
  error,
  status,
  refresh,
} = await useAsyncData<Facit[]>(
  'plants-with-images',
  async () => {
    const { data, error } = await supabase
      .from('facit')
      .select(
        'id, name, sv_name, images, images_reordered, images_reordered_date, images_added_date'
      )
      .not('images', 'is', null)
      .order('name');

    if (error) {
      console.error('Error fetching plants with images:', error);
      throw error;
    }

    return data || [];
  },
  {
    lazy: true,
  }
);

// Computed filtered plants based on selected filter
const filteredPlants = computed(() => {
  if (!plants.value) return [];

  switch (selectedFilter.value) {
    case 'reordered':
      return plants.value
        .filter((plant) => plant.images_reordered === true)
        .sort((a, b) => {
          return (
            new Date(b.images_reordered_date || '').getTime() -
            new Date(a.images_reordered_date || '').getTime()
          );
        });
    case 'not-reordered':
      return plants.value
        .filter((plant) => plant.images_reordered === false)
        .sort((a, b) => {
          return (
            new Date(b.images_added_date || '').getTime() -
            new Date(a.images_added_date || '').getTime()
          );
        });
    default:
      return plants.value.sort((a, b) => {
        return (
          new Date(b.images_added_date || '').getTime() -
          new Date(a.images_added_date || '').getTime()
        );
      });
  }
});

// Helper function to create plant slug
const slugify = (text: string) => {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9åäö\- ]/gi, '')
    .replace(/\s+/g, '+')
    .replace(/-+/g, '+')
    .replace(/^-+|-+$/g, '');
};

// Image error handling functions
const handleImageError = (imageKey: string, event: Event) => {
  imageLoadErrors.value.set(imageKey, true);
  console.warn('Image failed to load:', imageKey);
};

const handleImageLoad = (imageKey: string) => {
  imageLoadErrors.value.delete(imageKey);
};

// Force refresh of all image elements for a plant
const refreshPlantImages = (plantId: number) => {
  // Clear any error states for this plant
  const keysToDelete = Array.from(imageLoadErrors.value.keys()).filter((key) =>
    key.startsWith(`${plantId}-`)
  );
  keysToDelete.forEach((key) => imageLoadErrors.value.delete(key));

  // Force Vue to re-render by triggering reactivity
  nextTick(() => {
    // This will be called after the DOM updates
  });
};

// Image viewer functions
const openImageViewer = (images: any[], index: number = 0) => {
  // Create full images array with proper structure
  const allImages = images.map((img: any, idx: number) => ({
    src: img.url,
    alt: img.title || `Bild ${idx + 1}`,
  }));

  // Reorder array so clicked image comes first, then continue in circular order
  const reorderedImages = [
    ...allImages.slice(index), // From clicked image to end
    ...allImages.slice(0, index), // From start to clicked image
  ];

  currentImages.value = reorderedImages;
  currentImageIndex.value = 0; // Always start at 0 since clicked image is now first
  isImageViewerOpen.value = true;
};

const closeImageViewer = () => {
  isImageViewerOpen.value = false;
  currentImages.value = [];
  currentImageIndex.value = 0;
};

const updateImageIndex = (index: number) => {
  currentImageIndex.value = index;
};

// Function to open image viewer for search results
const openSearchImageViewer = (index: number) => {
  modalCurrentImages.value = searchResults.value.map((result: any, idx: number) => ({
    src: result.url, // Use the full resolution URL, not thumbnail
    alt: result.title || `Sökresultat ${idx + 1}`,
  }));
  modalCurrentImageIndex.value = index;
  isModalImageViewerOpen.value = true;
};

// Modal image viewer functions
const closeModalImageViewer = () => {
  isModalImageViewerOpen.value = false;
  modalCurrentImages.value = [];
  modalCurrentImageIndex.value = 0;
};

const updateModalImageIndex = (index: number) => {
  modalCurrentImageIndex.value = index;
};

const goToPreviousModalImage = () => {
  if (modalCurrentImageIndex.value > 0) {
    modalCurrentImageIndex.value--;
  }
};

const goToNextModalImage = () => {
  if (modalCurrentImageIndex.value < modalCurrentImages.value.length - 1) {
    modalCurrentImageIndex.value++;
  }
};

// Keyboard navigation for modal image viewer
const handleModalImageViewerKeydown = (event: KeyboardEvent) => {
  if (!isModalImageViewerOpen.value) return;

  switch (event.key) {
    case 'Escape':
      closeModalImageViewer();
      break;
    case 'ArrowLeft':
      goToPreviousModalImage();
      break;
    case 'ArrowRight':
      goToNextModalImage();
      break;
  }
};

// Add keyboard event listener when component mounts
onMounted(() => {
  document.addEventListener('keydown', handleModalImageViewerKeydown);
});

// Remove keyboard event listener when component unmounts
onUnmounted(() => {
  document.removeEventListener('keydown', handleModalImageViewerKeydown);
});

// Image manipulation functions
const moveImageLeft = async (plant: Facit, index: number) => {
  if (index === 0 || !plant.images) return;

  const images = [...plant.images];
  // Swap with previous image
  [images[index - 1], images[index]] = [images[index], images[index - 1]];

  // Update local state only
  plant.images = images;
  unsavedChanges.value.add(plant.id);

  // Refresh image elements to handle any load errors
  refreshPlantImages(plant.id);
};

const moveImageRight = async (plant: Facit, index: number) => {
  if (!plant.images || index === plant.images.length - 1) return;

  const images = [...plant.images];
  // Swap with next image
  [images[index], images[index + 1]] = [images[index + 1], images[index]];

  // Update local state only
  plant.images = images;
  unsavedChanges.value.add(plant.id);

  // Refresh image elements to handle any load errors
  refreshPlantImages(plant.id);
};

const makeImageFirst = async (plant: Facit, index: number) => {
  if (index === 0 || !plant.images) return;

  const images = [...plant.images];
  const imageToMove = images.splice(index, 1)[0];
  images.unshift(imageToMove);

  // Update local state only
  plant.images = images;
  unsavedChanges.value.add(plant.id);

  // Refresh image elements to handle any load errors
  refreshPlantImages(plant.id);
};

const deleteImage = async (plant: Facit, index: number) => {
  if (!plant.images) return;

  // Show confirmation dialog
  const confirmed = confirm(`Är du säker på att du vill ta bort denna bild från ${plant.name}?`);
  if (!confirmed) return;

  const images = [...plant.images];
  images.splice(index, 1);

  // Update local state only
  plant.images = images;
  unsavedChanges.value.add(plant.id);

  // Refresh image elements to handle any load errors
  refreshPlantImages(plant.id);
};

// Google image search functions
const searchImages = async (page: number = currentPage.value) => {
  if (!searchQuery.value.trim()) return;

  isSearching.value = true;
  searchError.value = '';
  searchResults.value = []; // Always clear results for single page display
  searchHasBeenPerformed.value = true;
  currentPage.value = page;

  try {
    const results = await $fetch('/api/image-search', {
      params: {
        q: searchQuery.value.trim(),
        start: (page - 1) * 10 + 1, // Google Custom Search uses 1-based indexing
      },
    });

    searchResults.value = results || [];

    // Calculate total pages (Google Custom Search API typically returns max 100 results, so 10 pages)
    totalPages.value = Math.min(10, Math.ceil(100 / 10));
  } catch (error) {
    console.error('Error searching images:', error);
    searchError.value = 'Fel vid sökning av bilder. Försök igen.';
  } finally {
    isSearching.value = false;
  }
};

const goToPage = (page: number) => {
  if (page >= 1 && page <= Math.max(totalPages.value, 10)) {
    currentPage.value = page;
  }
};

const addSearchResultToPlant = async (searchResult: any) => {
  if (!currentPlantForImage.value) return;

  isAddingImage.value = true;

  try {
    // Create new image object matching the expected structure
    const newImage = {
      url: searchResult.url,
      title: searchResult.title || '',
      sourcePage: searchResult.sourcePage || searchResult.url,
    };

    // Initialize images array if it doesn't exist
    if (!currentPlantForImage.value.images) {
      currentPlantForImage.value.images = [];
    }

    // Add the new image to the plant's images array
    currentPlantForImage.value.images.push(newImage);

    // Mark as having unsaved changes
    unsavedChanges.value.add(currentPlantForImage.value.id);

    // Show success message
    imageAddedSuccess.value = true;

    closeModalImageViewer();

    // Clear success message after 2 seconds
    setTimeout(() => {
      imageAddedSuccess.value = false;
    }, 2000);
  } catch (error) {
    console.error('Error adding search result:', error);
    alert('Fel vid tillägg av bild');
  } finally {
    isAddingImage.value = false;
  }
};

// Add image modal functions
const openAddImageModal = (plant: Facit) => {
  currentPlantForImage.value = plant;
  newImageUrl.value = '';
  newImageTitle.value = '';
  imageAddedSuccess.value = false;
  isAddImageModalOpen.value = true;

  // Pre-populate search with plant name
  searchQuery.value = plant.name;
  searchResults.value = [];
  searchError.value = '';
  searchHasBeenPerformed.value = false;
  currentPage.value = 1;
  totalPages.value = 1;
};

const closeAddImageModal = () => {
  isAddImageModalOpen.value = false;
  currentPlantForImage.value = null;
  newImageUrl.value = '';
  newImageTitle.value = '';
  imageAddedSuccess.value = false;
  isAddingImage.value = false;

  // Clear search state
  searchQuery.value = '';
  searchResults.value = [];
  searchError.value = '';
  isSearching.value = false;
  searchHasBeenPerformed.value = false;
  currentPage.value = 1;
  totalPages.value = 1;

  // Clear modal image viewer state
  isModalImageViewerOpen.value = false;
  modalCurrentImages.value = [];
  modalCurrentImageIndex.value = 0;
};

const addImageToPlant = async () => {
  if (!currentPlantForImage.value || !newImageUrl.value.trim()) return;

  isAddingImage.value = true;

  try {
    const imageUrl = newImageUrl.value.trim();
    const imageTitle = newImageTitle.value.trim() || null;

    // Create new image object matching the expected structure
    const newImage = {
      url: imageUrl,
      title: imageTitle || '', // Ensure title is never null
      sourcePage: imageUrl, // Use the URL as sourcePage for manually added images
    };

    // Initialize images array if it doesn't exist
    if (!currentPlantForImage.value.images) {
      currentPlantForImage.value.images = [];
    }

    // Add the new image to the plant's images array
    currentPlantForImage.value.images.push(newImage);

    // Mark as having unsaved changes
    unsavedChanges.value.add(currentPlantForImage.value.id);

    // Show success message
    imageAddedSuccess.value = true;

    // Clear form
    newImageUrl.value = '';
    newImageTitle.value = '';

    // Auto-close modal after 1.5 seconds
    setTimeout(() => {
      closeAddImageModal();
    }, 1500);
  } catch (error) {
    console.error('Error adding image:', error);
    alert('Fel vid tillägg av bild');
  } finally {
    isAddingImage.value = false;
  }
};

const savePlantChanges = async (plant: Facit) => {
  try {
    const now = new Date().toISOString();
    // Update the plant in the database with type assertion to handle Supabase typing
    const { error } = await (supabase as any)
      .from('facit')
      .update({
        images: plant.images,
        images_reordered: true,
        images_reordered_date: now,
      })
      .eq('id', plant.id);

    if (error) {
      console.error('Error updating plant images:', error);
      alert('Fel vid uppdatering av bilder');
      return;
    }

    // Update local state
    plant.images_reordered = true;
    plant.images_reordered_date = now;

    // Remove from unsaved changes
    unsavedChanges.value.delete(plant.id);

    console.log(`Saved changes for ${plant.name}: ${plant.images?.length || 0} images`);

    // If we deleted all images, refresh the data
    if (!plant.images || plant.images.length === 0) {
      await refresh();
    }
  } catch (err) {
    console.error('Unexpected error:', err);
    alert('Oväntat fel vid uppdatering av bilder');
  }
};

// Function to mark images as reordered without making actual changes
const markAsReordered = async (plant: Facit) => {
  try {
    const now = new Date().toISOString();
    // Update only the reordered status and date
    const { error } = await (supabase as any)
      .from('facit')
      .update({
        images_reordered: true,
        images_reordered_date: now,
      })
      .eq('id', plant.id);

    if (error) {
      console.error('Error marking plant as reordered:', error);
      alert('Fel vid markering som granskad');
      return;
    }

    // Update local state
    plant.images_reordered = true;
    plant.images_reordered_date = now;

    console.log(`Marked ${plant.name} as reordered/reviewed`);
  } catch (err) {
    console.error('Unexpected error:', err);
    alert('Oväntat fel vid markering som granskad');
  }
};

// Function to unmark images as reordered (set back to not reordered)
const unmarkAsReordered = async (plant: Facit) => {
  try {
    // Update to set reordered status to false and clear the date
    const { error } = await (supabase as any)
      .from('facit')
      .update({
        images_reordered: false,
        images_reordered_date: null,
      })
      .eq('id', plant.id);

    if (error) {
      console.error('Error unmarking plant as reordered:', error);
      alert('Fel vid markering som ej granskad');
      return;
    }

    // Update local state
    plant.images_reordered = false;
    plant.images_reordered_date = null;

    console.log(`Unmarked ${plant.name} as reordered/reviewed`);
  } catch (err) {
    console.error('Unexpected error:', err);
    alert('Oväntat fel vid markering som ej granskad');
  }
};
</script>

<template>
  <div class="p-4 md:p-8 w-full">
    <div class="flex justify-between items-center mb-6 max-md:flex-col max-md:gap-2">
      <h1 class="text-3xl font-bold">Bildhantering</h1>

      <!-- Filter Controls -->
      <div class="flex items-center gap-4">
        <UButton
          @click="refresh"
          color="primary"
          variant="outline"
          icon="i-heroicons-arrow-path"
          size="sm"
        >
          Uppdatera
        </UButton>
        <div class="flex items-center gap-2">
          <label for="reorder-filter" class="text-sm font-medium">Visa bilder:</label>
          <USelect
            id="reorder-filter"
            v-model="selectedFilter"
            :items="filterOptions"
            value-attribute="value"
            option-attribute="label"
          />
        </div>
        <div class="text-sm text-t-toned">{{ filteredPlants.length }} växter</div>
      </div>
    </div>

    <!-- Loading State -->
    <div v-if="status === 'pending'" class="flex items-center justify-center py-12">
      <UIcon name="i-heroicons-arrow-path" class="animate-spin w-8 h-8" />
      <span class="ml-2">Laddar växter...</span>
    </div>

    <!-- Error State -->
    <div v-else-if="error" class="bg-error-bg border border-error rounded-lg p-4">
      <div class="flex items-center">
        <UIcon name="i-heroicons-exclamation-triangle" class="text-error w-5 h-5 mr-2" />
        <span class="text-error/70">Fel vid laddning av växter: {{ error }}</span>
      </div>
    </div>

    <!-- Plants List -->
    <div v-else-if="filteredPlants.length === 0" class="text-center py-12">
      <UIcon name="i-heroicons-photo" class="w-16 h-16 text-t-muted mx-auto mb-4" />
      <h3 class="text-lg font-medium mb-2">Inga växter hittades</h3>
      <p class="text-t-toned">
        {{
          selectedFilter === 'reordered'
            ? 'Inga växter med omordnade bilder.'
            : selectedFilter === 'not-reordered'
            ? 'Inga växter med icke-omordnade bilder.'
            : 'Inga växter med sparade bilder.'
        }}
      </p>
    </div>

    <!-- Plants with Images -->
    <div v-else class="">
      <div
        v-for="plant in filteredPlants"
        :key="plant.id"
        class="border border-border rounded-lg p-4 mt-4"
        :class="{ 'border-error': unsavedChanges.has(plant.id) }"
      >
        <!-- Plant Header -->
        <div class="flex items-start justify-between mb-4">
          <div>
            <div class="md:flex md:items-center md:gap-4">
              <h2 class="text-xl font-semibold">
                {{ plant.name }}
                <span v-if="unsavedChanges.has(plant.id)" class="text-error">*</span>
              </h2>
              <p v-if="plant.sv_name" class="text-t-toned italic">
                {{ plant.sv_name }}
              </p>
            </div>
            <div class="flex items-center gap-4 mt-2 text-sm text-t-muted max-md:flex-wrap">
              <span>ID: {{ plant.id }}</span>
              <span>{{ plant.images?.length || 0 }} bilder</span>
              <UBadge :color="plant.images_reordered ? 'primary' : 'info'" variant="soft" size="sm">
                {{ plant.images_reordered ? 'Omordnade' : 'Ursprungsordning' }}
              </UBadge>
              <span class="flex gap-x-2 text-xs">
                <span v-if="plant.images_reordered_date">
                  Uppdaterade:
                  {{
                    new Date(plant.images_reordered_date).toLocaleDateString('sv-SE', {
                      year: 'numeric',
                      month: 'short',
                      day: 'numeric',
                      hour: '2-digit',
                      minute: '2-digit',
                    })
                  }}
                </span>
                <span v-if="plant.images_added_date">
                  Från google:
                  {{
                    new Date(plant.images_added_date).toLocaleDateString('sv-SE', {
                      year: 'numeric',
                      month: 'short',
                      day: 'numeric',
                      hour: '2-digit',
                      minute: '2-digit',
                    })
                  }}
                </span>
              </span>
            </div>
          </div>
          <div class="flex gap-2">
            <UButton
              v-if="unsavedChanges.has(plant.id)"
              @click="savePlantChanges(plant)"
              icon="i-heroicons-check"
              color="primary"
              size="sm"
            >
              Spara
            </UButton>
            <!-- Mark as reordered button (only show if not already reordered and no unsaved changes) -->
            <UTooltip text="Markera som granskad" :delay-duration="0">
              <UButton
                v-if="!plant.images_reordered && !unsavedChanges.has(plant.id)"
                @click="markAsReordered(plant)"
                icon="i-heroicons-check"
                color="success"
                size="sm"
                variant="outline"
              >
              </UButton>
            </UTooltip>
            <!-- Unmark as reordered button (only show if already reordered and no unsaved changes) -->
            <UTooltip text="Markera som ej granskad" :delay-duration="0">
              <UButton
                v-if="plant.images_reordered && !unsavedChanges.has(plant.id)"
                @click="unmarkAsReordered(plant)"
                icon="i-heroicons-x-mark"
                color="warning"
                size="sm"
                variant="outline"
              >
              </UButton>
            </UTooltip>
            <UTooltip text="Lägg till bild" :delay-duration="0">
              <UButton
                @click="openAddImageModal(plant)"
                icon="i-heroicons-plus"
                color="success"
                size="sm"
                variant="outline"
              >
              </UButton>
            </UTooltip>
            <UTooltip text="Öppna växtens sida" :delay-duration="0">
              <UButton
                :to="`/vaxt/${plant.id}/${slugify(plant.name)}`"
                target="_blank"
                icon="i-heroicons-arrow-top-right-on-square"
                variant="outline"
                size="sm"
              ></UButton>
            </UTooltip>
          </div>
        </div>

        <!-- Images Grid -->
        <div
          v-if="plant.images && plant.images.length > 0"
          class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-10 gap-3"
        >
          <div
            v-for="(image, index) in plant.images"
            :key="`${plant.id}-${index}-${image.url}`"
            class="image-container relative aspect-square rounded-lg overflow-hidden"
          >
            <img
              :src="image.url"
              :alt="image.title || `${plant.name} - Bild ${index + 1}`"
              class="w-full h-full object-cover cursor-pointer hover:opacity-90 transition-opacity"
              loading="lazy"
              @click="openImageViewer(plant.images, index)"
              @error="handleImageError(`${plant.id}-${index}-${image.url}`, $event)"
              @load="handleImageLoad(`${plant.id}-${index}-${image.url}`)"
            />

            <!-- Image Overlay Info -->
            <div class="image-overlay absolute inset-0 opacity-0 transition-opacity duration-300">
              <div
                class="w-full h-full p-2 text-white text-xs flex flex-col justify-between"
                @click="openImageViewer(plant.images, index)"
              >
                <!-- Actions -->
                <div
                  class="flex items-center justify-between gap-2 bg-black/70 rounded-md p-2"
                  @click.stop
                >
                  <UButton
                    class="disabled:opacity-50"
                    icon="material-symbols:arrow-back-rounded"
                    color="neutral"
                    :disabled="index === 0"
                    @click.stop="moveImageLeft(plant, index)"
                  ></UButton>
                  <UButton
                    class="flex-1 grow flex justify-center disabled:opacity-50"
                    color="primary"
                    :disabled="index === 0"
                    @click.stop="makeImageFirst(plant, index)"
                  >
                    Först
                  </UButton>
                  <UButton
                    class=""
                    icon="material-symbols:delete-outline-rounded"
                    color="error"
                    @click.stop="deleteImage(plant, index)"
                  ></UButton>
                  <UButton
                    class="disabled:opacity-50"
                    icon="material-symbols:arrow-forward-rounded"
                    color="neutral"
                    :disabled="index === plant.images.length - 1"
                    @click.stop="moveImageRight(plant, index)"
                  ></UButton>
                </div>
                <!-- Title -->
                <div class="bg-black/60 rounded-md px-2 py-1 flex gap-1" @click.stop>
                  <div class="text-gray-300 text-xs">{{ index + 1 }}.</div>
                  <UTooltip :text="image.title || 'Utan titel'" :delay-duration="0">
                    <ULink
                      :to="image.sourcePage"
                      target="_blank"
                      class="font-medium truncate text-white hover:text-white/70"
                      >{{ image.title || 'Utan titel' }}</ULink
                    >
                  </UTooltip>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- No Images State -->
        <div v-else class="text-center py-8 bg-bg-elevated rounded-lg">
          <UIcon name="i-heroicons-photo" class="w-12 h-12 text-t-toned mx-auto mb-2" />
          <p class="text-t-muted">Inga bilder sparade</p>
        </div>
      </div>
    </div>

    <!-- Image Viewer Modal -->
    <ImageViewer
      v-if="currentImages.length > 0"
      :images="currentImages"
      :initial-index="currentImageIndex"
      :is-open="isImageViewerOpen"
      @close="closeImageViewer"
      @update:current-index="updateImageIndex"
    />

    <!-- Add Image Modal -->
    <UModal v-model:open="isAddImageModalOpen">
      <template #header>
        <h2 class="text-lg font-semibold">
          Lägg till bild{{ currentPlantForImage ? ` - ${currentPlantForImage.name}` : '' }}
        </h2>
      </template>
      <template #body>
        <div class="flex flex-col gap-6">
          <!-- Manual URL Input Section -->
          <div class="space-y-4">
            <h4 class="font-medium">Lägg till från URL</h4>
            <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
              <div class="space-y-4">
                <div>
                  <label class="block text-sm font-medium mb-1">Bild-URL</label>
                  <UInput
                    v-model="newImageUrl"
                    placeholder="Klistra in bild-URL här"
                    clearable
                    :disabled="isAddingImage"
                  />
                </div>
                <div>
                  <label class="block text-sm font-medium mb-1">Bildtitel (valfritt)</label>
                  <UInput
                    v-model="newImageTitle"
                    placeholder="Ange bildtitel"
                    clearable
                    :disabled="isAddingImage"
                  />
                </div>
                <UButton
                  @click="addImageToPlant"
                  color="primary"
                  class="w-full"
                  :loading="isAddingImage"
                  :disabled="!newImageUrl || isAddingImage"
                >
                  Lägg till bild
                </UButton>
                <div v-if="imageAddedSuccess" class="text-sm text-success">
                  Bilden har lagts till!
                </div>
              </div>
              <div v-if="newImageUrl" class="flex items-center justify-center">
                <div class="border border-border rounded-lg overflow-hidden max-w-full">
                  <img
                    :src="newImageUrl"
                    :alt="newImageTitle || 'Förhandsvisning'"
                    class="max-h-48 w-auto object-cover"
                  />
                </div>
              </div>
            </div>
          </div>

          <!-- Google Search Section -->
          <div class="border-t border-border pt-6 space-y-4">
            <h4 class="font-medium">Sök efter bilder</h4>
            <div class="flex gap-2">
              <UInput
                v-model="searchQuery"
                placeholder="Sök efter bilder..."
                class="flex-1"
                @keyup.enter="() => searchImages(currentPage)"
              />
              <!-- Page Input -->
              <div class="flex items-center gap-1 border border-border rounded-lg bg-bg">
                <UButton
                  @click="goToPage(currentPage - 1)"
                  icon="i-heroicons-minus"
                  color="neutral"
                  variant="ghost"
                  size="xs"
                  :disabled="currentPage <= 1"
                />
                <span
                  class="px-3 py-1 text-sm font-semibold min-w-[3rem] text-center border-x border-border"
                  >{{ currentPage }}</span
                >
                <UButton
                  @click="goToPage(currentPage + 1)"
                  icon="i-heroicons-plus"
                  color="neutral"
                  variant="ghost"
                  size="xs"
                  :disabled="currentPage >= 10"
                />
              </div>
              <UButton
                @click="() => searchImages(currentPage)"
                color="primary"
                :loading="isSearching"
                :disabled="!searchQuery.trim() || isSearching"
              >
                Sök
              </UButton>
            </div>

            <!-- Search Error -->
            <div v-if="searchError" class="text-sm text-error">
              {{ searchError }}
            </div>

            <!-- Search Results Grid -->
            <div v-if="searchResults.length > 0" class="space-y-2">
              <div class="flex items-center">
                <p class="text-sm text-t-toned">
                  {{ searchResults.length }} resultat på sida {{ currentPage }} av {{ totalPages }}
                </p>
              </div>
              <div
                class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-3 max-h-96 overflow-y-auto"
              >
                <div
                  v-for="(result, index) in searchResults"
                  :key="index"
                  class="search-result-container relative aspect-square rounded-lg overflow-hidden group cursor-pointer"
                >
                  <img
                    :src="result.url"
                    :alt="result.title"
                    class="w-full h-full object-cover transition-opacity group-hover:opacity-75"
                    loading="lazy"
                    @click="openSearchImageViewer(index)"
                  />

                  <!-- Hover Overlay with Add Button -->
                  <div
                    class="absolute inset-0 bg-black/50 opacity-0 group-hover:opacity-100 transition-opacity duration-200 flex items-center justify-center"
                    @click="openSearchImageViewer(index)"
                  >
                    <UButton
                      @click.stop="addSearchResultToPlant(result)"
                      color="primary"
                      size="sm"
                      icon="i-heroicons-plus"
                      :loading="isAddingImage"
                    >
                      Lägg till
                    </UButton>
                  </div>

                  <!-- Image Title Tooltip -->
                  <div
                    class="absolute bottom-0 left-0 right-0 bg-black/70 text-white text-xs p-2 opacity-0 group-hover:opacity-100 transition-opacity duration-200"
                  >
                    <UTooltip :text="result.title" :delay-duration="0">
                      <p class="truncate">{{ result.title }}</p>
                    </UTooltip>
                  </div>
                </div>
              </div>
            </div>

            <!-- No Results -->
            <div
              v-else-if="
                searchQuery && !isSearching && searchResults.length === 0 && searchHasBeenPerformed
              "
              class="text-center py-8 text-t-toned"
            >
              <UIcon
                name="i-heroicons-magnifying-glass"
                class="w-12 h-12 mx-auto mb-2 opacity-50"
              />
              <p>Inga bilder hittades för "{{ searchQuery }}" på sida {{ currentPage }}</p>
            </div>
          </div>
        </div>

        <!-- Integrated Image Viewer -->
        <UModal
          v-model:open="isModalImageViewerOpen"
          fullscreen
          class="bg-black/90 z-50 flex items-center justify-center"
        >
          <template #content class="relative w-full h-full flex items-center justify-center p-4">
            <!-- Close Button -->
            <UButton
              @click="closeModalImageViewer"
              icon="i-heroicons-x-mark"
              color="neutral"
              class="absolute top-4 right-4 z-10 p-2 text-white bg-transparent border-none"
            >
            </UButton>

            <!-- Previous Button -->
            <UButton
              v-if="modalCurrentImageIndex > 0"
              @click="goToPreviousModalImage"
              icon="i-heroicons-chevron-left"
              color="neutral"
              class="absolute left-4 top-1/2 -translate-y-1/2 z-10 p-2 text-white bg-transparent border-none"
            >
            </UButton>

            <!-- Next Button -->
            <UButton
              v-if="modalCurrentImageIndex < modalCurrentImages.length - 1"
              @click="goToNextModalImage"
              icon="i-heroicons-chevron-right"
              color="neutral"
              class="absolute right-4 top-1/2 -translate-y-1/2 z-10 p-2 text-white bg-transparent border-none"
            >
            </UButton>

            <!-- Image -->
            <div class="relative max-w-full max-h-full">
              <img
                :src="modalCurrentImages[modalCurrentImageIndex]?.src"
                :alt="modalCurrentImages[modalCurrentImageIndex]?.alt"
                class="max-w-full max-h-full object-contain"
              />

              <!-- Image Info -->
              <div class="absolute bottom-0 left-0 right-0 bg-black/70 text-white p-4 border-none">
                <p class="text-sm">
                  {{ modalCurrentImageIndex + 1 }} / {{ modalCurrentImages.length }}
                </p>
                <p class="font-medium">
                  {{ modalCurrentImages[modalCurrentImageIndex]?.alt }}
                </p>
              </div>
            </div>

            <!-- Add Image Button -->
            <div class="absolute bottom-4 right-4 z-10">
              <UButton
                v-if="searchResults[modalCurrentImageIndex]"
                @click="addSearchResultToPlant(searchResults[modalCurrentImageIndex])"
                color="primary"
                icon="i-heroicons-plus"
                :loading="isAddingImage"
              >
                Lägg till denna bild
              </UButton>
            </div>
          </template>
        </UModal>
      </template>
      <template #footer>
        <UButton @click="isAddImageModalOpen = false" variant="outline" color="neutral">
          Stäng
        </UButton>
      </template>
    </UModal>
  </div>
</template>

<style scoped>
.image-container:hover .image-overlay {
  opacity: 1;
}

.search-result-container {
  border: 2px solid transparent;
  transition: border-color 0.2s ease;
}

.search-result-container:hover {
  border-color: rgb(var(--color-primary-500));
}

/* Add any custom styles if needed */
</style>
