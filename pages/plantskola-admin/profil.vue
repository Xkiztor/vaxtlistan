<script setup lang="ts">
// SEO metadata for plantskola profil admin page
useHead({
  title: 'Min profil - Admin - Växtlistan',
  meta: [
    {
      name: 'description',
      content: 'Uppdatera din plantskola-profil på Växtlistan. Ändra kontaktinformation, beskrivning och andra inställningar.',
    },
    {
      name: 'robots',
      content: 'noindex, nofollow', // Admin pages should not be indexed
    },
  ],
});

definePageMeta({
  layout: 'admin',
  middleware: 'plantskola-admin',
});

import type { Plantskola } from '~/types/supabase-tables';

const supabase = useSupabaseClient();
const user = useSupabaseUser();
const toast = useToast();
const loading = ref(false);
const error = ref<string | null>(null);
const success = ref(false);

// Reactive form for editing
const form = ref<
  Partial<Plantskola & { phone?: string; description?: string; verified?: boolean }>
>({});

// Fetch current plantskola info for logged-in user
const { data: plantskola, refresh } = await useAsyncData('plantskola', async () => {
  if (!user.value) return null;
  const { data, error } = await supabase
    .from('plantskolor')
    .select('*')
    .eq('user_id', user.value.id)
    .single();
  if (error || !data) return null;
  return data;
});

// Initialize form with fetched data
watchEffect(() => {
  if (plantskola.value) {
    form.value = { ...(plantskola.value as Plantskola) };
  }
});

// Save changes to Supabase
async function save() {
  error.value = null;
  success.value = false;
  loading.value = true;
  try {
    if (!user.value) throw new Error('Ingen användare inloggad.');

    // Check if email is changed
    const emailChanged = form.value.email && form.value.email !== user.value.email; // Always update plantskolor table first with current form data
    const updatePayload = {
      name: form.value.name || '',
      adress: form.value.adress || '',
      email: form.value.email || '',
      phone: form.value.phone || '',
      url: form.value.url || '',
      postorder: form.value.postorder || false,
      on_site: form.value.on_site || false,
      description: form.value.description || '',
      last_edited: new Date().toISOString(),
    };

    const { error: updateError } = await (supabase as any)
      .from('plantskolor')
      .update(updatePayload)
      .eq('user_id', user.value.id);
    if (updateError) throw new Error(updateError.message);

    // If email was changed, also update it in Supabase Auth
    if (emailChanged) {
      const { error: authError } = await supabase.auth.updateUser({ email: form.value.email });
      if (authError) {
        // Auth email update failed, but plantskolor table was updated
        toast.add({
          title: 'Profil uppdaterad',
          description: 'Profilen sparades men e-poständring misslyckades. Försök igen senare.',
          color: 'warning',
        });
      } else {
        // Auth email update succeeded
        toast.add({
          title: 'Profil uppdaterad',
          description:
            'Profilen har sparats. En bekräftelselänk har skickats till din nya e-postadress för att slutföra e-poständringen.',
          color: 'primary',
        });
      }
    } else {
      // No email change, just regular update
      toast.add({ title: 'Uppdaterad', description: 'Profilen har sparats.' });
    }

    success.value = true;
    await refresh();
  } catch (e: any) {
    error.value = e.message;
    toast.add({ title: 'Fel', description: e.message, color: 'error' });
  } finally {
    loading.value = false;
  }
}
</script>

<template>
  <div class="flex flex-col items-center justify-center min-h-[calc(100vh-5rem)] p-4">
    <div class="w-full max-w-lg border-1 border-border p-6 rounded-lg bg-bg-elevated">
      <h1 class="text-2xl font-bold mb-4">
        Min plantskola
        <UIcon
          name="material-symbols:verified-rounded"
          class="text-secondary"
          v-if="form.verified"
        />
      </h1>
      <form @submit.prevent="save" class="flex flex-col gap-4">
        <UFormField label="Namn på plantskola" required>
          <UInput v-model="form.name" required class="w-full" />
        </UFormField>
        <UFormField label="Adress" required>
          <UInput
            v-model="form.adress"
            required
            placeholder="Gatuadress, postnummer och stad"
            class="w-full"
          />
        </UFormField>
        <UFormField label="Beskrivning av plantskola">
          <UTextarea v-model="form.description" class="w-full" />
        </UFormField>
        <UFormField label="Telefonnummer">
          <UInput v-model="form.phone" type="tel" class="w-full" />
        </UFormField>
        <UFormField label="Webbsida">
          <UInput v-model="form.url" type="url" placeholder="https://..." class="w-full" />
        </UFormField>
        <UFormField label="Postorder">
          <UCheckbox v-model="form.postorder" />
        </UFormField>
        <UFormField label="Hämtning på plats">
          <UCheckbox v-model="form.on_site" />
        </UFormField>
        <UFormField label="E-post" required>
          <UInput v-model="form.email" type="email" required class="w-full" />
        </UFormField>
        <div class="flex flex-col gap-2 mt-2 w-fit">
          <div class="flex items-center gap-2 w-fit">
            <span class="font-semibold">Verifierad: </span>
            <UBadge :color="form.verified ? 'secondary' : 'error'">
              {{ form.verified ? 'Ja' : 'Nej' }}
            </UBadge>
          </div>
          <div class="opacity-60 flex items-center gap-2" v-if="!form.verified">
            <UIcon name="material-symbols:info-outline-rounded" size="20" class="w-20" />
            <p class="text-sm">
              Dina växter kommer inte att synas för andra förrän du är verifierad. Vi kommer att
              verifiera dig så snart som möjligt. Du kan fortfarande använda tjänsten som vanligt
              under tiden.
            </p>
          </div>
        </div>
        <UButton type="submit" :loading="loading" color="primary" class="w-full">
          Spara ändringar
        </UButton>
      </form>
      <div v-if="error" class="text-error mt-2">{{ error }}</div>
      <div v-if="success" class="text-primary mt-2">Profilen har sparats!</div>
    </div>
  </div>
</template>

<style scoped>
/* Only use Tailwind or Nuxt UI classes, no custom colors */
</style>
