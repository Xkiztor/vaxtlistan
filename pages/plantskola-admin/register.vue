<script setup lang="ts">
// Registration page for nursery owners (plantskolor)
// Uses Supabase Auth and inserts into plantskolor table

// SEO metadata for plantskola registration page
useHead({
  title: 'Registrera plantskola - Växtlistan',
  meta: [
    {
      name: 'description',
      content:
        'Registrera din plantskola på Växtlistan och nå ut till fler kunder. Enkelt att komma igång och visa ditt växtsortiment.',
    },
    {
      name: 'keywords',
      content:
        'registrera plantskola, plantskola växtlistan, växtförsäljning online, växtsortiment, plantskolor sverige',
    },
    {
      property: 'og:title',
      content: 'Registrera plantskola - Växtlistan',
    },
    {
      property: 'og:description',
      content: 'Registrera din plantskola på Växtlistan och nå ut till fler kunder.',
    },
    {
      property: 'og:type',
      content: 'website',
    },
    {
      property: 'og:url',
      content: 'https://vaxtlistan.se/plantskola-admin/register',
    },
    {
      name: 'twitter:card',
      content: 'summary',
    },
    {
      name: 'twitter:title',
      content: 'Registrera plantskola - Växtlistan',
    },
    {
      name: 'twitter:description',
      content: 'Registrera din plantskola på Växtlistan och nå ut till fler kunder.',
    },
  ],
  link: [
    {
      rel: 'canonical',
      href: 'https://vaxtlistan.se/plantskola-admin/register',
    },
  ],
});

definePageMeta({
  layout: 'empty',
});

// Types for form fields
interface RegisterForm {
  name: string;
  gatuadress: string;
  postnummer: string;
  postort: string;
  description: string;
  tel: string;
  url: string;
  postorder: boolean;
  on_site: boolean;
  email: string;
  password: string;
}

const form = ref<RegisterForm>({
  name: '',
  gatuadress: '',
  postnummer: '',
  postort: '',
  description: '',
  tel: '',
  url: '',
  postorder: false,
  on_site: true,
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
    } // 2. Insert into plantskolor table
    const { error: dbError } = await (supabase as any).from('plantskolor').insert({
      name: form.value.name,
      gatuadress: form.value.gatuadress,
      postnummer: form.value.postnummer,
      postort: form.value.postort,
      email: form.value.email,
      phone: form.value.tel,
      url: form.value.url,
      postorder: form.value.postorder,
      on_site: form.value.on_site,
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
          <UInput v-model="form.name" required :ui="{ root: 'w-full' }" />
        </UFormField>
        <UFormField label="Gatuadress" required>
          <UInput v-model="form.gatuadress" required :ui="{ root: 'w-full' }" placeholder="" />
        </UFormField>
        <div class="flex flex-row gap-4">
          <UFormField label="Postnummer" required>
            <UInput
              v-model="form.postnummer"
              required
              :ui="{ root: 'w-full' }"
              placeholder=""
              type="text"
              inputmode="numeric"
              pattern="[0-9]{5}"
            />
          </UFormField>
          <UFormField label="Postort" required>
            <UInput v-model="form.postort" required :ui="{ root: 'w-full' }" placeholder="" />
          </UFormField>
        </div>
        <UFormField label="Beskrivning av plantskola">
          <UTextarea v-model="form.description" :ui="{ root: 'w-full' }" />
        </UFormField>
        <UFormField label="Telefonnummer" type="tel">
          <UInput v-model="form.tel" type="tel" :ui="{ root: 'w-full' }" />
        </UFormField>
        <UFormField label="Webbsida">
          <UInput
            v-model="form.url"
            type="url"
            placeholder="https://..."
            :ui="{ root: 'w-full' }"
          />
        </UFormField>
        <UFormField label="Postorder">
          <UCheckbox v-model="form.postorder" />
        </UFormField>
        <UFormField label="Hämtning på plats">
          <UCheckbox v-model="form.on_site" />
        </UFormField>
        <UFormField label="E-post" type="email" required>
          <UInput v-model="form.email" type="email" required :ui="{ root: 'w-full' }" />
        </UFormField>
        <UFormField label="Lösenord" type="password" required>
          <UInput v-model="form.password" type="password" required :ui="{ root: 'w-full' }" />
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
