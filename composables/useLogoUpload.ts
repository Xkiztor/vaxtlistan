// composables/useLogoUpload.ts

interface LogoUploadResponse {
  url: string;
  originalUrl: string;
  publicId: string;
}

interface LogoUploadError {
  message: string;
  statusCode?: number;
}

export const useLogoUpload = () => {
  const uploading = ref(false);
  const uploadError = ref<string | null>(null);

  /**
   * Upload logo file to Cloudinary
   * @param file - File object to upload
   * @returns Promise with upload result
   */
  const uploadFile = async (file: File): Promise<LogoUploadResponse | null> => {
    uploading.value = true;
    uploadError.value = null;

    try {
      // Validate file type
      const allowedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/svg+xml'];
      if (!allowedTypes.includes(file.type)) {
        throw new Error('Endast JPG, PNG, WebP och SVG-filer är tillåtna');
      }

      // Validate file size (5MB limit)
      const maxSize = 5 * 1024 * 1024; // 5MB
      if (file.size > maxSize) {
        throw new Error('Filen är för stor. Max storlek är 5MB');
      }

      const formData = new FormData();
      formData.append('file', file);

      const result = await $fetch<LogoUploadResponse>('/api/upload-logo', {
        method: 'POST',
        body: formData,
      });

      return result;
    } catch (error: any) {
      console.error('Logo upload error:', error);
      uploadError.value = error.message || 'Ett oväntat fel uppstod';
      return null;
    } finally {
      uploading.value = false;
    }
  };

  /**
   * Upload logo from URL to Cloudinary
   * @param url - Image URL to upload
   * @returns Promise with upload result
   */
  const uploadFromUrl = async (url: string): Promise<LogoUploadResponse | null> => {
    uploading.value = true;
    uploadError.value = null;

    try {
      // Validate URL format
      try {
        new URL(url);
      } catch {
        throw new Error('Ogiltig URL-format');
      }
      
      // Allow any https URL but warn about unknown domains
      if (!url.startsWith('https://')) {
        throw new Error('Endast HTTPS-URLs är tillåtna av säkerhetsskäl');
      }

      const formData = new FormData();
      formData.append('url', url);

      const result = await $fetch<LogoUploadResponse>('/api/upload-logo', {
        method: 'POST',
        body: formData,
      });

      return result;
    } catch (error: any) {
      console.error('Logo upload from URL error:', error);
      uploadError.value = error.message || 'Ett oväntat fel uppstod';
      return null;
    } finally {
      uploading.value = false;
    }
  };

  /**
   * Validate logo URL format
   * @param url - URL to validate
   * @returns boolean indicating if URL is valid
   */
  const isValidLogoUrl = (url: string): boolean => {
    try {
      const urlObj = new URL(url);
      return urlObj.protocol === 'https:';
    } catch {
      return false;
    }
  };

  /**
   * Get optimized logo URL with transformations
   * @param originalUrl - Original Cloudinary URL
   * @param options - Transformation options
   * @returns Optimized URL
   */
  const getOptimizedLogoUrl = (
    originalUrl: string, 
  ): string => {
    if (!originalUrl.includes('cloudinary.com')) {
      return originalUrl;
    }

    return originalUrl.replace(
      '/upload/', 
      `/upload/f_auto/`
    );
  };

  return {
    uploading: readonly(uploading),
    uploadError: readonly(uploadError),
    uploadFile,
    uploadFromUrl,
    isValidLogoUrl,
    getOptimizedLogoUrl,
  };
};
