<script setup lang="ts">
/**
 * LogoUploader Component
 *
 * Handles logo upload functionality with both file upload and URL input
 * Supports drag & drop, file validation, and preview
 */

interface Props {
  /** Current logo URL */
  modelValue?: string | null;
  /** Whether upload is disabled */
  disabled?: boolean;
  /** Loading state */
  loading?: boolean;
}

interface Emits {
  (e: 'update:modelValue', value: string | null): void;
  (e: 'uploaded', result: { url: string; originalUrl: string; publicId: string }): void;
  (e: 'error', error: string): void;
}

const props = withDefaults(defineProps<Props>(), {
  modelValue: null,
  disabled: false,
  loading: false,
});

const emit = defineEmits<Emits>();

// Composables
const { uploading, uploadError, uploadFile, uploadFromUrl, isValidLogoUrl, getOptimizedLogoUrl } =
  useLogoUpload();
const toast = useToast();

// Reactive state
const fileInputRef = ref<HTMLInputElement>();
const dropZoneRef = ref<HTMLDivElement>();
const urlInput = ref('');
const isDragging = ref(false);
const showUrlInput = ref(false);
const previewUrl = ref<string | null>(props.modelValue);

// Watch for external changes to modelValue
watch(
  () => props.modelValue,
  (newValue) => {
    previewUrl.value = newValue;
  }
);

/**
 * Handle file selection from input
 */
const handleFileSelect = async (event: Event) => {
  const target = event.target as HTMLInputElement;
  const file = target.files?.[0];

  if (file) {
    await handleFileUpload(file);
  }

  // Reset input for next selection
  if (target) target.value = '';
};

/**
 * Handle file upload logic
 */
const handleFileUpload = async (file: File) => {
  const result = await uploadFile(file);

  if (result) {
    previewUrl.value = result.url;
    emit('update:modelValue', result.url);
    emit('uploaded', result);
    toast.add({
      title: 'Logotyp uppladdad',
      description: 'Din logotyp har laddats upp!',
      color: 'primary',
    });
  } else if (uploadError.value) {
    emit('error', uploadError.value);
    toast.add({
      title: 'Uppladdning misslyckades',
      description: uploadError.value,
      color: 'error',
    });
  }
};

/**
 * Handle URL upload
 */
const handleUrlUpload = async () => {
  if (!urlInput.value.trim()) return;

  if (!isValidLogoUrl(urlInput.value.trim())) {
    toast.add({
      title: 'Ogiltig URL',
      description: 'Ange en giltig HTTPS-URL till en bild',
      color: 'error',
    });
    return;
  }

  const result = await uploadFromUrl(urlInput.value.trim());

  if (result) {
    previewUrl.value = result.url;
    emit('update:modelValue', result.url);
    emit('uploaded', result);
    urlInput.value = '';
    showUrlInput.value = false;
    toast.add({
      title: 'Logotyp uppladdad',
      description: 'Din logotyp har laddats upp från URL',
      color: 'primary',
    });
  } else if (uploadError.value) {
    emit('error', uploadError.value);
    toast.add({
      title: 'Uppladdning misslyckades',
      description: uploadError.value,
      color: 'error',
    });
  }
};

/**
 * Handle drag and drop events
 */
const handleDragOver = (event: DragEvent) => {
  event.preventDefault();
  isDragging.value = true;
};

const handleDragLeave = (event: DragEvent) => {
  event.preventDefault();
  isDragging.value = false;
};

const handleDrop = async (event: DragEvent) => {
  event.preventDefault();
  isDragging.value = false;

  const files = event.dataTransfer?.files;
  if (files && files.length > 0) {
    await handleFileUpload(files[0]);
  }
};

/**
 * Remove current logo
 */
const removeLogo = () => {
  previewUrl.value = null;
  emit('update:modelValue', null);
  toast.add({
    title: 'Logotyp borttagen',
    description: 'Logotypen har tagits bort',
    color: 'primary',
  });
};

/**
 * Open file picker
 */
const openFilePicker = () => {
  fileInputRef.value?.click();
};

// Computed
const isUploading = computed(() => uploading.value || props.loading);
const hasLogo = computed(() => Boolean(previewUrl.value));
const optimizedPreviewUrl = computed(() =>
  previewUrl.value ? getOptimizedLogoUrl(previewUrl.value, { width: 200, height: 100 }) : null
);
</script>

<template>
  <div class="space-y-4">
    <!-- Current Logo Preview -->
    <div
      v-if="hasLogo"
      class="flex items-center justify-between p-4 border border-border rounded-lg bg-bg-elevated"
    >
      <div class="flex items-center gap-4">
        <div class="h-16">
          <img
            v-if="optimizedPreviewUrl"
            :src="optimizedPreviewUrl"
            alt="Logotyp förhandsvisning"
            class="max-w-full max-h-full object-contain"
          />
          <UIcon
            v-else
            name="material-symbols:image-outline-rounded"
            class="w-8 h-8 text-t-toned"
          />
        </div>
        <div>
          <p class="font-medium text-sm">Aktuell logotyp</p>
          <!-- <p class="text-xs text-t-toned">Klicka för att ändra eller ta bort</p> -->
        </div>
      </div>
      <UButton
        variant="outline"
        color="error"
        size="sm"
        :disabled="isUploading"
        @click="removeLogo"
      >
        <UIcon name="material-symbols:delete-outline-rounded" />
        Ta bort
      </UButton>
    </div>

    <!-- Upload Area -->
    <div
      ref="dropZoneRef"
      class="border-2 border-dashed rounded-lg p-6 text-center transition-colors"
      :class="{
        'border-primary bg-primary/10': isDragging,
        'border-border hover:border-primary/50': !isDragging,
        'opacity-50 cursor-not-allowed': isUploading || disabled,
      }"
      @dragover="handleDragOver"
      @dragleave="handleDragLeave"
      @drop="handleDrop"
    >
      <div class="space-y-4">
        <!-- Upload Icon -->
        <div class="mx-auto flex items-center justify-center" v-if="isUploading">
          <UIcon name="ant-design:loading-outlined" class="w-6 h-6 text-primary animate-spin" />
        </div>

        <!-- Upload Text -->
        <div>
          <h3 class="text-lg font-medium">
            {{
              isUploading
                ? 'Laddar upp...'
                : 'Ladda upp logotyp - kvadratisk och gärna genomskinlig'
            }}
          </h3>
          <p class="text-sm text-t-toned mt-1">
            Dra och släpp en bild här, eller klicka för att välja en fil
          </p>
          <p class="text-xs text-t-toned mt-2">Stöder JPG, PNG, WebP och SVG (max 5MB)</p>
        </div>

        <!-- Upload Buttons -->
        <div class="flex flex-col sm:flex-row gap-2 justify-center">
          <UButton
            :disabled="isUploading || disabled"
            :loading="isUploading"
            @click="openFilePicker"
            color="primary"
            variant="solid"
          >
            <UIcon name="material-symbols:folder-open-outline-rounded" />
            Välj fil
          </UButton>

          <UButton
            :disabled="isUploading || disabled"
            @click="showUrlInput = !showUrlInput"
            color="primary"
            variant="outline"
          >
            <UIcon name="material-symbols:link-rounded" />
            Från URL
          </UButton>
        </div>

        <!-- URL Input Section -->
        <div v-if="showUrlInput" class="border-t border-border pt-4 space-y-3">
          <div class="flex gap-2 justify-center">
            <UInput
              v-model="urlInput"
              placeholder="https://example.com/logo.png"
              :disabled="isUploading || disabled"
              class="max-w-md"
            >
            </UInput>
            <UButton
              size="xs"
              :disabled="!urlInput.trim() || isUploading || disabled"
              :loading="isUploading"
              @click="handleUrlUpload"
              color="primary"
            >
              Ladda upp
            </UButton>
          </div>
          <p class="text-xs text-t-toned">Ange URL till en bild som ska användas som logotyp</p>
        </div>
      </div>
    </div>

    <!-- Hidden file input -->
    <input
      ref="fileInputRef"
      type="file"
      accept="image/jpeg,image/jpg,image/png,image/webp,image/svg+xml"
      class="hidden"
      @change="handleFileSelect"
    />

    <!-- Error Message -->
    <div v-if="uploadError" class="text-error text-sm flex items-center gap-2">
      <UIcon name="material-symbols:error-outline-rounded" />
      {{ uploadError }}
    </div>
  </div>
</template>

<style scoped>
/* Use only Tailwind and CSS variables from main.css */
</style>
