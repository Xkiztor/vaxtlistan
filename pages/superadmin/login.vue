<script setup lang="ts">
// Use Nuxt composables and Supabase client

// State for email, password, and loading
const email = ref('');
const password = ref('');
const loading = ref(false);
const error = ref('');
const router = useRouter();
const toast = useToast();

// Handle login with Supabase email + password
const handleLogin = async () => {
  error.value = '';
  loading.value = true;
  const supabase = useSupabaseClient();
  try {
    // Sign in with email and password
    const { data: authData, error: signInError } = await supabase.auth.signInWithPassword({
      email: email.value,
      password: password.value,
    });
    if (signInError) throw signInError;
    // Check if user is in superadmins table
    const user = authData.user;
    const { data: superadmin, error: fetchError } = await supabase
      .from('superadmins')
      .select('id')
      .eq('user_id', user.id)
      .single();
    if (superadmin) {
      toast.add({ title: 'Inloggad', description: 'Välkommen, superadmin!' });
      router.replace('/superadmin');
    } else {
      await supabase.auth.signOut();
      error.value = 'Du har inte behörighet som superadmin.';
    }
  } catch (e: any) {
    error.value = e.message || 'Fel vid inloggning.';
  } finally {
    loading.value = false;
  }
};

definePageMeta({
  layout: 'superadmin',
  middleware: 'superadmin',
});
</script>

<template>
  <UContainer class="flex flex-col items-center justify-center min-h-screen">
    <UCard class="w-full max-w-md mt-10">
      <h1 class="text-2xl font-bold mb-4">Superadmin Login</h1>
      <form @submit.prevent="handleLogin" autocomplete="on">
        <UFormGroup label="E-post" required>
          <UInput
            v-model="email"
            name="email"
            type="email"
            autocomplete="username"
            placeholder="Din e-post"
            required
            class="mb-4"
          />
        </UFormGroup>
        <UFormGroup label="Lösenord" required>
          <UInput
            v-model="password"
            name="password"
            type="password"
            autocomplete="current-password"
            placeholder="Ditt lösenord"
            required
            class="mb-4"
          />
        </UFormGroup>
        <UButton type="submit" :loading="loading" class="w-full mb-2">Logga in</UButton>
      </form>
      <UContainer v-if="error" type="error" class="mt-2">{{ error }}</UContainer>
    </UCard>
  </UContainer>
</template>

<style scoped>
/* Add any custom styles if needed */
</style>
