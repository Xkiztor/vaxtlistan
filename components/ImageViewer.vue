<template>
  <div
    v-if="isOpen"
    class="fixed inset-0 bg-black/80 z-50 flex items-center justify-center p-4"
    @click="handleBackdropClick"
  >
    <!-- Close button -->
    <UButton
      icon="i-heroicons-x-mark"
      size="xl"
      color="neutral"
      variant="ghost"
      class="absolute top-4 right-4 z-10 text-white hover:opacity-40 hover:bg-transparent"
      @click="close"
    />

    <!-- Source link button - bottom left -->
    <!-- <ULink
      v-if="images.length > 0 && currentImage?.sourcePage"
      icon="i-heroicons-link"
      :to="currentImage.sourcePage"
      target="_blank"
      rel="noopener noreferrer"
      class="absolute bottom-4 left-4 z-10 text-white/50 hover:text-white/80"
      :title="`Källa: ${currentImage.title || 'Extern länk'}`"
    >
      {{ currentImage.title || 'Källa' }}
      <UIcon name="i-heroicons-arrow-top-right-on-square" />
    </ULink> -->
    <!-- Image carousel container -->
    <div
      class="relative w-full h-full flex items-center justify-center"
      @click="handleContainerClick"
    >
      <UCarousel
        v-if="images.length > 0"
        v-slot="{ item }"
        :items="images"
        :ui="{
          item: 'basis-full shrink-0 h-full w-full translate-x-2',
          container: 'h-full w-full',
          viewport: 'h-full w-full',
          prev: 'left-0 max-md:hidden',
          next: 'right-0 max-md:hidden',
        }"
        :page="currentIndex"
        class="w-full h-full max-w-7xl mx-auto"
        arrows
        loop
        @update:page="updateCurrentIndex"
      >
        <div
          class="h-full w-full flex items-center justify-center p-0 md:p-8"
          @click="handleImageAreaClick"
        >
          <img
            :src="item.src"
            :alt="item.alt || 'Image'"
            class="max-w-full max-h-[calc(100vh-8rem)] object-contain rounded-lg shadow-2xl"
            loading="lazy"
            @click.stop
          />
          <ULink
            v-if="item.sourcePage"
            icon="i-heroicons-link"
            :to="item.sourcePage"
            target="_blank"
            rel="noopener noreferrer"
            class="absolute -bottom-1 left-2 z-10 text-white/40 hover:text-white/60"
            :title="`Källa: ${item.title || 'Extern länk'}`"
          >
            {{ item.title || 'Källa' }}
            <UIcon name="i-heroicons-arrow-top-right-on-square" />
          </ULink>
        </div>
      </UCarousel>
    </div>
  </div>
</template>

<script setup lang="ts">
const testFunc = (event) => {
  console.log('Carousel item selected:', event);
};
/**
 * ImageViewer Component
 *
 * A reusable modal component for displaying images in full size with carousel functionality.
 * Features:
 * - Full screen overlay
 * - Image carousel navigation with UCarousel
 * - Click outside to close
 * - Close button
 * - Image counter
 * - Keyboard navigation (ESC to close)
 */

// Define the image interface
interface ImageItem {
  src: string;
  alt?: string;
  sourcePage?: string;
  title?: string;
}

// Component props
interface Props {
  images: ImageItem[];
  initialIndex?: number;
  isOpen: boolean;
}

// Component emits
interface Emits {
  (e: 'close'): void;
  (e: 'update:currentIndex', index: number): void;
}

// Define props with defaults
const props = withDefaults(defineProps<Props>(), {
  initialIndex: 0,
  images: () => [],
});

// Define emits
const emit = defineEmits<Emits>();

// Reactive state for current image index
const currentIndex = ref(props.initialIndex);

// Computed property to ensure we have a valid current image
const currentImage = computed(() => {
  const index = Math.max(0, Math.min(currentIndex.value, props.images.length - 1));
  return props.images[index];
});

// Reset to initial index when viewer opens
watch(
  () => props.isOpen,
  (isOpen) => {
    if (isOpen) {
      currentIndex.value = props.initialIndex;
    }
  }
);

// Watch for changes to initialIndex
watch(
  () => props.initialIndex,
  (newIndex) => {
    if (props.isOpen) {
      currentIndex.value = newIndex;
    }
  }
);

/**
 * Handle backdrop click to close the viewer
 */
const handleBackdropClick = (event: MouseEvent) => {
  // Only close if clicking on the backdrop itself, not on child elements
  if (event.target === event.currentTarget) {
    close();
  }
};

/**
 * Close the image viewer
 */
const close = () => {
  emit('close');
};

/**
 * Update current image index
 */
const updateCurrentIndex = (index: number) => {
  // Ensure the index is within valid bounds
  const validIndex = Math.max(0, Math.min(index, props.images.length - 1));
  currentIndex.value = validIndex;
  emit('update:currentIndex', validIndex);
};

/**
 * Handle keyboard events
 */
const handleKeydown = (event: KeyboardEvent) => {
  if (!props.isOpen) return;

  switch (event.key) {
    case 'Escape':
      close();
      break;
    case 'ArrowLeft':
      // Handle looping: go to last image if at first
      const prevIndex = currentIndex.value > 0 ? currentIndex.value - 1 : props.images.length - 1;
      updateCurrentIndex(prevIndex);
      break;
    case 'ArrowRight':
      // Handle looping: go to first image if at last
      const nextIndex = currentIndex.value < props.images.length - 1 ? currentIndex.value + 1 : 0;
      updateCurrentIndex(nextIndex);
      break;
  }
};

// Add keyboard event listeners when component is mounted
onMounted(() => {
  document.addEventListener('keydown', handleKeydown);
});

// Remove keyboard event listeners when component is unmounted
onUnmounted(() => {
  document.removeEventListener('keydown', handleKeydown);
});

// Prevent body scroll when viewer is open
watch(
  () => props.isOpen,
  (isOpen) => {
    if (process.client) {
      if (isOpen) {
        document.body.style.overflow = 'hidden';
      } else {
        document.body.style.overflow = '';
      }
    }
  }
);

// Cleanup on unmount
onUnmounted(() => {
  if (process.client) {
    document.body.style.overflow = '';
  }
});

/**
 * Handle container click - closes viewer when clicking outside image area
 */
const handleContainerClick = (event: MouseEvent) => {
  const target = event.target as HTMLElement;

  // Don't close if clicking on carousel controls (arrows, dots, etc.) or source link
  if (
    target.closest('button') ||
    target.closest('[role="button"]') ||
    target.closest('.carousel-control') ||
    target.tagName === 'BUTTON' ||
    target.classList.contains('carousel-arrow') ||
    target.classList.contains('carousel-dot') ||
    target.closest('a') ||
    target.tagName === 'A'
  ) {
    return;
  }

  // Close the viewer when clicking in the container area (outside the image)
  close();
};

/**
 * Handle image area click - prevents closing when clicking in the image area
 */
const handleImageAreaClick = (event: MouseEvent) => {
  const target = event.target as HTMLElement;

  // Don't close if clicking on carousel controls or source link
  if (
    target.closest('button') ||
    target.closest('[role="button"]') ||
    target.tagName === 'BUTTON' ||
    target.closest('a') ||
    target.tagName === 'A'
  ) {
    return;
  }

  // Check if click is on the padding area around the image (not the image itself)
  if (target.tagName !== 'IMG') {
    // Clicked on padding area around image, close the viewer
    close();
  }
  // If clicked on IMG element, the @click.stop on the img will prevent propagation
};
</script>

<style scoped>
/* Custom styles for smooth transitions */
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.3s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
</style>
