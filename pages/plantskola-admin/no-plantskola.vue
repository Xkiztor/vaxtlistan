<template>
  <div class="min-h-screen flex flex-col justify-center py-12 sm:px-6 lg:px-8">
    <div class="sm:mx-auto sm:w-full sm:max-w-md">
      <!-- Logo or Header -->
      <div class="text-center">
        <h1 class="text-3xl font-bold mb-2">Konto ej kopplat</h1>
        <p class="text-t-toned mb-8">Ditt konto är inte kopplat till någon plantskola</p>
      </div>

      <!-- Main Card -->
      <div class="py-4">
        <div class="text-center space-y-6">
          <!-- Icon -->
          <div class="mx-auto flex items-center justify-center h-16 w-16 rounded-full bg-info-bg">
            <UIcon name="i-heroicons-exclamation-triangle" class="h-8 w-8 text-info" />
          </div>

          <!-- Message -->
          <div class="space-y-2">
            <h2 class="text-xl font-semibold">Ingen plantskola hittad</h2>
            <p class="text-t-toned text-sm leading-relaxed">
              Ditt nuvarande konto är inte kopplat till någon registrerad plantskola. Testa att
              logga ut och in igen eller kontakta oss för hjälp.
            </p>
          </div>

          <!-- Actions -->
          <div class="space-y-4">
            <!-- Register new plantskola button -->
            <UButton
              to="/plantskola-admin/register"
              color="primary"
              variant="outline"
              size="lg"
              block
              class="justify-center"
            >
              Registrera plantskola
            </UButton>

            <!-- Logout button -->
            <UButton
              @click="handleLogout"
              color="error"
              size="lg"
              block
              class="justify-center"
              :loading="isLoggingOut"
            >
              Logga ut
            </UButton>
          </div>

          <!-- Help text -->
          <div class="text-xs text-t-muted pt-4 border-t">
            <p>Behöver du hjälp? Kontakta oss på ugo.linder@gmail.com</p>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
// Page meta for SEO and layout
definePageMeta({
  layout: 'empty',
  title: 'Konto ej kopplat till plantskola',
});

// Composables
const supabase = useSupabaseClient();
const router = useRouter();

// Reactive state
const isLoggingOut = ref(false);

// Handle user logout
const handleLogout = async () => {
  try {
    isLoggingOut.value = true;

    // Sign out user from Supabase
    const { error } = await supabase.auth.signOut();

    if (error) {
      console.error('Error signing out:', error);
      // Still redirect even if there's an error
    }

    // Redirect to login page
    await router.push('/plantskola-admin/login');
  } catch (error) {
    console.error('Unexpected error during logout:', error);
    // Redirect anyway to prevent user being stuck
    await router.push('/plantskola-admin/login');
  } finally {
    isLoggingOut.value = false;
  }
};

// SEO meta tags
useHead({
  title: 'Konto ej kopplat till plantskola - Växtlistan',
  meta: [
    {
      name: 'description',
      content:
        'Ditt konto är inte kopplat till någon plantskola. Registrera din plantskola eller logga ut.',
    },
    {
      name: 'robots',
      content: 'noindex, nofollow',
    },
  ],
});
</script>

<style scoped>
/* Additional component-specific styles if needed */
</style>
