<script setup lang="ts">
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
    form.value = { ...plantskola.value };
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
    const emailChanged = form.value.email && form.value.email !== user.value.email;
    if (emailChanged) {
      // Update email in Supabase Auth first
      const { error: authError } = await supabase.auth.updateUser({ email: form.value.email });
      if (authError) throw new Error('Kunde inte uppdatera e-post: ' + authError.message);
      toast.add({
        title: 'Bekräfta ny e-post',
        description:
          'En bekräftelselänk har skickats till din nya e-postadress. E-postadressen ändras först när du bekräftar via länken.',
        color: 'primary',
      });
      loading.value = false;
      return;
    }
    // Update plantskolor table
    const { error: updateError } = await supabase
      .from('plantskolor')
      .update({
        name: form.value.name,
        adress: form.value.adress,
        email: form.value.email,
        phone: form.value.phone,
        description: form.value.description,
        last_edited: new Date().toISOString(),
      })
      .eq('user_id', user.value.id);
    if (updateError) throw new Error(updateError.message);
    toast.add({ title: 'Uppdaterad', description: 'Profilen har sparats.' });
    success.value = true;
    await refresh();
  } catch (e: any) {
    error.value = e.message;
    toast.add({ title: 'Fel', description: e.message, color: 'red' });
  } finally {
    loading.value = false;
  }
}
</script>

<template>
  <div class="flex flex-col items-center justify-center min-h-[calc(100vh-5rem)] p-4">
    <div class="w-full max-w-lg border-1 border-regular p-6 rounded-lg bg-elevated">
      <h1 class="text-2xl font-bold mb-4">Min plantskola</h1>
      <form @submit.prevent="save" class="flex flex-col gap-4">
        <UFormField label="Namn på plantskola" required>
          <UInput v-model="form.name" required class="w-full" />
        </UFormField>
        <UFormField label="Adress" required>
          <UInput v-model="form.adress" required class="w-full" />
        </UFormField>
        <UFormField label="Beskrivning av plantskola">
          <UTextarea v-model="form.description" class="w-full" />
        </UFormField>
        <UFormField label="Telefonnummer">
          <UInput v-model="form.phone" type="tel" class="w-full" />
        </UFormField>
        <UFormField label="E-post" required>
          <UInput v-model="form.email" type="email" required class="w-full" />
        </UFormField>
        <div class="flex flex-col gap-2 mt-2 w-fit">
          <div class="flex items-center gap-2 w-fit">
            <span class="font-semibold">Verifierad: </span>
            <UBadge :color="form.verified ? 'primary' : 'error'">
              {{ form.verified ? 'Ja' : 'Nej' }}
            </UBadge>
          </div>
          <div class="opacity-60 flex items-center gap-2">
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
