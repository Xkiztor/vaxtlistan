<script setup lang="ts">
// Use Nuxt composables and Supabase client
const user = useSupabaseUser();
const supabase = useSupabaseClient();
const router = useRouter();
const toast = useToast();

import type { Plantskola } from '~/types/supabase-tables';

// Use useAsyncData for SSR and better load times
const {
  data: unverifiedPlantskolor,
  status,
  refresh,
} = await useAsyncData('unverifiedPlantskolor', async () => {
  const { data, error } = await supabase.from('plantskolor').select('*').eq('verified', false);
  if (error) {
    toast.add({ title: 'Fel', description: 'Kunde inte hämta plantskolor.' });
    return [];
  }
  return data as Plantskola[];
});

// Handler to verify a plantskola
const handleVerify = async (id: number) => {
  const { error } = await supabase.from('plantskolor').update({ verified: true }).eq('id', id);
  if (error) {
    toast.add({ title: 'Fel', description: 'Kunde inte verifiera.' });
  } else {
    toast.add({ title: 'Verifierad', description: 'Plantskolan är nu verifierad.' });
    refresh(); // Refresh the async data
  }
};

// Handler to delete a plantskola
const handleDelete = async (id: number) => {
  const { error } = await supabase.from('plantskolor').delete().eq('id', id);
  if (error) {
    toast.add({ title: 'Fel', description: 'Kunde inte ta bort.' });
  } else {
    toast.add({ title: 'Borttagen', description: 'Plantskolan har tagits bort.' });
    refresh(); // Refresh the async data
  }
};

// Logout function for superadmin
const handleLogout = async () => {
  await supabase.auth.signOut();
  toast.add({ title: 'Utloggad', description: 'Du har loggats ut.' });
  router.replace('/superadmin/login');
};

definePageMeta({
  layout: 'superadmin',
  middleware: 'superadmin',
});
</script>

<template>
  <div>
    <div>
      <h1 class="font-black text-3xl">Plantskolor</h1>
      <div>
        <h1>Overifierade:</h1>
        <ul class="flex flex-col gap-4 py-2">
          <li
            v-for="plantskola in unverifiedPlantskolor"
            :key="plantskola.id"
            class="flex gap-4 border-regular border-1 p-4 rounded-md"
          >
            <div>
              <span class="font-bold text-xl">{{ plantskola.name }}</span>
              <div class="flex gap-2 flex-wrap mt-2">
                <span class="text-toned">{{ plantskola.email }}</span>
                <span class="text-toned">{{ plantskola.phone }}</span>
                <span class="text-toned">{{ plantskola.adress }}</span>
              </div>
            </div>
            <div>
              <span class="text-toned">{{
                plantskola.created_at.replace('T', ' ').slice(0, 16)
              }}</span>
              <div class="flex gap-2 mt-2">
                <UButton color="success" @click="handleVerify(plantskola.id)">Verifiera</UButton>
                <UButton color="error" variant="outline" @click="handleDelete(plantskola.id)"
                  >Ta bort</UButton
                >
              </div>
            </div>
          </li>
        </ul>
        <div v-if="status === 'pending'">Laddar...</div>
      </div>
      <UButton color="primary" to="/superadmin/plantskolor">Visa alla</UButton>
    </div>
  </div>
</template>

<style scoped>
/* Add any custom styles if needed */
</style>
