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
} = await useAsyncData(
  'unverifiedPlantskolor',
  async () => {
    const { data, error } = await supabase.from('plantskolor').select('*').eq('verified', false);
    if (error) {
      toast.add({ title: 'Fel', description: 'Kunde inte hämta plantskolor.' });
      return [];
    }
    return data as Plantskola[];
  },
  {
    lazy: true,
  }
);

// Fetch the 5 latest user-submitted plants from facit
const { data: latestUserPlants, status: latestUserPlantsStatus } = await useAsyncData(
  'latestUserPlants',
  async () => {
    const { data, error } = await supabase
      .from('facit')
      .select('id, name, sv_name, created_at')
      .eq('user_submitted', true)
      .order('created_at', { ascending: false })
      .limit(5);
    if (error) {
      toast.add({ title: 'Fel', description: 'Kunde inte hämta senaste växterna.' });
      return [];
    }
    return data;
  },
  {
    lazy: true,
  }
);

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
  <div class="space-y-8 px-4">
    <div class="md:grid md:grid-cols-2 gap-8">
      <!-- Plantskolor -->
      <div class="border-1 border-border rounded-lg p-4">
        <h1 class="font-black text-3xl">Plantskolor</h1>
        <div>
          <h1 v-if="unverifiedPlantskolor?.length">Overifierade:</h1>
          <h1 v-else class="text-primary text-lg font-bold">Alla är verifierade!</h1>
          <ul class="flex flex-col gap-4 py-2">
            <li
              v-for="plantskola in unverifiedPlantskolor"
              :key="plantskola.id"
              class="flex gap-4 border-border border-1 p-4 rounded-md"
            >
              <div>
                <span class="font-bold text-xl">{{ plantskola.name }}</span>
                <div class="flex gap-2 flex-wrap mt-2">
                  <span class="text-t-toned">{{ plantskola.email }}</span>
                  <span class="text-t-toned">{{ plantskola.phone }}</span>
                  <span class="text-t-toned">{{ plantskola.adress }}</span>
                </div>
              </div>
              <div>
                <span class="text-t-toned">{{
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
      <!-- Senaste användartillagda växter -->
      <div class="border-1 border-border rounded-lg p-4">
        <h2 class="font-bold text-xl mb-2">Senaste växter tillagda av användare</h2>
        <div v-if="latestUserPlantsStatus === 'pending'">Laddar...</div>
        <ul v-else class="flex flex-col gap-2">
          <li
            v-for="plant in latestUserPlants"
            :key="plant.id"
            class="flex justify-between items-center border-b border-border py-2"
          >
            <span>
              <span class="font-semibold">{{ plant.name }}</span>
              <span v-if="plant.sv_name" class="text-t-toned ml-2">({{ plant.sv_name }})</span>
            </span>
            <span class="text-xs text-t-muted">{{
              plant.created_at.replace('T', ' ').slice(0, 16)
            }}</span>
          </li>
          <li v-if="latestUserPlants && latestUserPlants.length === 0" class="italic text-t-muted">
            Inga växter tillagda av användare ännu.
          </li>
        </ul>
      </div>
    </div>
  </div>
</template>

<style scoped>
/* Add any custom styles if needed */
</style>
