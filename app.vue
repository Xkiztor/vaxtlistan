<script setup lang="ts">
// Global error handling
const handleGlobalError = (error: any, errorInfo?: string) => {
  console.error('Global error caught:', error, errorInfo);

  // In production, you might want to send to error tracking service
  if (process.env.NODE_ENV === 'production') {
    // TODO: Send to error tracking service (e.g., Sentry)
  }
};

// Set up global error handler
onErrorCaptured((error: Error, instance, info) => {
  handleGlobalError(error, info);
  // Don't propagate the error further
  return false;
});

// Global SEO defaults
useHead({
  htmlAttrs: {
    lang: 'sv',
  },
  meta: [
    { charset: 'utf-8' },
    { name: 'viewport', content: 'width=device-width, initial-scale=1' },
    { name: 'format-detection', content: 'telephone=no' },
  ],
});
</script>

<template>
  <div id="app">
    <UApp>
      <NuxtLayout>
        <NuxtPage />
      </NuxtLayout>
    </UApp>
  </div>
</template>
