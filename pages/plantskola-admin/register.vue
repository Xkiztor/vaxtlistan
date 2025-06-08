<script setup lang="ts">
// Registration page for nursery owners (plantskolor)
// Uses Supabase Auth and inserts into plantskolor table

definePageMeta({
  layout: 'empty',
});

// Types for form fields
interface RegisterForm {
  name: string;
  adress: string;
  description: string;
  tel: string;
  email: string;
  password: string;
}

const form = ref<RegisterForm>({
  name: '',
  adress: '',
  description: '',
  tel: '',
  email: '',
  password: '',
});

const loading = ref(false);
const error = ref<string | null>(null);
const success = ref(false);

const supabase = useSupabaseClient();
const router = useRouter();

// Handles registration process
async function register() {
  error.value = null;
  success.value = false;
  loading.value = true;
  try {
    // 1. Create user in Supabase Auth
    const { data: authData, error: authError } = await supabase.auth.signUp({
      email: form.value.email,
      password: form.value.password,
    });
    if (authError || !authData.user) {
      throw new Error(authError?.message || 'Kunde inte skapa användare.');
    }
    // 2. Insert into plantskolor table
    const { error: dbError } = await supabase.from('plantskolor').insert({
      name: form.value.name,
      adress: form.value.adress,
      email: form.value.email,
      phone: form.value.tel,
      description: form.value.description,
      user_id: authData.user.id,
      verified: false,
    });
    if (dbError) {
      throw new Error(dbError.message);
    }
    success.value = true;
    // Redirect to admin dashboard after short delay
    setTimeout(() => router.push('/plantskola-admin'), 1500);
  } catch (e: any) {
    error.value = e.message;
  } finally {
    loading.value = false;
  }
}
</script>

<template>
  <div class="flex flex-col items-center justify-center min-h-screen bg-bg-elevated p-4">
    <UCard class="w-full max-w-md">
      <h1 class="text-2xl font-bold mb-4">Registrera din plantskola</h1>
      <form @submit.prevent="register" class="flex flex-col gap-4">
        <UFormField label="Namn på plantskola" required>
          <UInput v-model="form.name" required />
        </UFormField>
        <UFormField label="Adress" required>
          <UInput v-model="form.adress" required />
        </UFormField>
        <UFormField label="Beskrivning av plantskola">
          <UTextarea v-model="form.description" />
        </UFormField>
        <UFormField label="Telefonnummer" type="tel">
          <UInput v-model="form.tel" type="tel" />
        </UFormField>
        <UFormField label="E-post" type="email" required>
          <UInput v-model="form.email" type="email" required />
        </UFormField>
        <UFormField label="Lösenord" type="password" required>
          <UInput v-model="form.password" type="password" required />
        </UFormField>

        <UButton type="submit" :loading="loading" class="w-full bg-primary text-white"
          >Registrera</UButton
        >
      </form>
      <div v-if="error" class="text-error mt-2">{{ error }}</div>
      <div v-if="success" class="text-primary mt-2">Registrering lyckades! Omdirigerar...</div>
      <div class="mt-4 text-center">
        <NuxtLink to="/plantskola-admin/login" class="text-primary underline"
          >Redan registrerad? Logga in</NuxtLink
        >
      </div>
    </UCard>
  </div>
</template>

<style scoped>
/* Add any custom styles if needed */
</style>
