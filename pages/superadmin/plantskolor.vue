<script setup lang="ts">
definePageMeta({
  layout: 'superadmin',
  middleware: 'superadmin',
});

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
    const { data, error } = await supabase.from('plantskolor').select('*');
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

// Handler to verify a plantskola
const handleVerify = async (id: number) => {
  const { error } = await (supabase as any)
    .from('plantskolor')
    .update({ verified: true })
    .eq('id', id);
  if (error) {
    toast.add({ title: 'Fel', description: 'Kunde inte verifiera.' });
  } else {
    toast.add({ title: 'Verifierad', description: 'Plantskolan är nu verifierad.' });
    refresh(); // Refresh the async data
  }
};
// Handler to verify a plantskola
const handleUnVerify = async (id: number) => {
  const { error } = await (supabase as any)
    .from('plantskolor')
    .update({ verified: false })
    .eq('id', id);
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
</script>

<template>
  <div>
    <!-- <UButton to="/superadmin/">Tillbaka</UButton> -->
    <ul class="flex flex-col gap-4 py-2">
      <li
        v-for="plantskola in unverifiedPlantskolor"
        :key="plantskola.id"
        class="flex gap-4 border-border border-1 p-4 rounded-md"
      >
        <div>
          <span class="font-bold text-xl"
            >{{ plantskola.name }}
            <UIcon
              name="material-symbols:verified-rounded"
              class="text-secondary"
              v-if="plantskola.verified"
          /></span>
          <div class="flex gap-2 flex-wrap mt-2">
            <span class="text-t-toned">{{ plantskola.email }}</span>
            <span class="text-t-toned">{{ plantskola.phone }}</span>
            <span class="text-t-toned">{{ plantskola.adress }}</span>
            <span v-if="plantskola.url" class="text-t-toned">
              <UButton
                :href="plantskola.url"
                target="_blank"
                variant="ghost"
                size="xs"
                icon="i-heroicons-globe-alt"
              >
                Webbsida
              </UButton>
            </span>
            <UBadge
              v-if="plantskola.postorder !== undefined"
              :color="plantskola.postorder ? 'success' : 'neutral'"
              variant="soft"
              size="sm"
            >
              {{ plantskola.postorder ? 'Postorder' : 'Endast hämtning' }}
            </UBadge>
            <UBadge
              v-if="plantskola.on_site !== undefined"
              :color="plantskola.on_site ? 'success' : 'neutral'"
              variant="soft"
              size="sm"
            >
              {{ plantskola.on_site ? 'Hämtning på plats' : 'Ingen hämtning' }}
            </UBadge>
          </div>
        </div>
        <div>
          <span class="text-t-toned">{{
            plantskola.created_at.replace('T', ' ').slice(0, 16)
          }}</span>
          <div class="flex gap-2 mt-2">
            <UButton
              v-if="!plantskola.verified"
              color="success"
              @click="handleVerify(plantskola.id)"
              >Verifiera</UButton
            >
            <UButton v-else color="error" @click="handleUnVerify(plantskola.id)"
              >Overifiera</UButton
            >
            <UButton color="primary" :to="`/plantskola/${plantskola.id}`"
              >Gå till plantskola</UButton
            >
            <UButton color="error" variant="outline" @click="handleDelete(plantskola.id)"
              >Ta bort</UButton
            >
          </div>
        </div>
      </li>
    </ul>
    <div v-if="status === 'pending'">Laddar...</div>
  </div>
</template>

<style></style>
