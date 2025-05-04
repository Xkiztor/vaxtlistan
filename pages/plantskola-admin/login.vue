<script setup lang="ts">
// Login page for nursery owners (plantskolor)
// Uses Supabase Auth

definePageMeta({
  layout: 'empty',
  middleware: 'redirect-if-logged-in',
});

interface LoginForm {
  email: string;
  password: string;
}

const form = ref<LoginForm>({
  email: '',
  password: '',
});

const loading = ref(false);
const error = ref<string | null>(null);

const supabase = useSupabaseClient();
const router = useRouter();

// Handles login process
async function login() {
  error.value = null;
  loading.value = true;
  try {
    const { error: authError } = await supabase.auth.signInWithPassword({
      email: form.value.email,
      password: form.value.password,
    });
    if (authError) {
      throw new Error(authError.message);
    }
    // Redirect to admin dashboard
    router.push('/plantskola-admin');
  } catch (e: any) {
    error.value = e.message;
  } finally {
    loading.value = false;
  }
}
</script>

<template>
  <div class="flex flex-col items-center justify-center min-h-screen bg-elevated p-4">
    <UCard class="w-full max-w-md">
      <h1 class="text-2xl font-bold mb-4">Plantskola Login</h1>
      <form @submit.prevent="login" class="flex flex-col gap-4">
        <UInput v-model="form.email" label="E-post" type="email" required />
        <UInput v-model="form.password" label="Lösenord" type="password" required />
        <UButton type="submit" :loading="loading" class="w-full bg-primary text-white"
          >Logga in</UButton
        >
      </form>
      <div v-if="error" class="text-error mt-2">{{ error }}</div>
      <div class="mt-6 text-center">
        <NuxtLink to="/plantskola-admin/register" class="text-primary underline text-lg"
          >Ny plantskola? Registrera dig</NuxtLink
        >
      </div>
    </UCard>
  </div>
</template>

<style scoped>
/* Add any custom styles if needed */
</style>
