<script setup lang="ts">
// SEO metadata for superadmin plantskolor page
useHead({
  title: 'Plantskolor - Superadmin - Växtlistan',
  meta: [
    {
      name: 'robots',
      content: 'noindex, nofollow', // Admin pages should not be indexed
    },
  ],
});

definePageMeta({
  layout: 'superadmin',
  middleware: 'superadmin',
});

// Use Nuxt composables and Supabase client
const user = useSupabaseUser();
const supabase = useSupabaseClient();
const router = useRouter();
const toast = useToast();

// State for confirmation modals
const isDeleteModalOpen = ref(false);
const isVerifyModalOpen = ref(false);
const selectedPlantskola = ref<Plantskola | null>(null);
const actionType = ref<'verify' | 'unverify' | 'delete'>('verify');

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
  const plantskola = unverifiedPlantskolor.value?.find((p) => p.id === id);
  if (plantskola) {
    selectedPlantskola.value = plantskola;
    actionType.value = 'verify';
    isVerifyModalOpen.value = true;
  }
};

// Handler to unverify a plantskola
const handleUnVerify = async (id: number) => {
  const plantskola = unverifiedPlantskolor.value?.find((p) => p.id === id);
  if (plantskola) {
    selectedPlantskola.value = plantskola;
    actionType.value = 'unverify';
    isVerifyModalOpen.value = true;
  }
};

// Handler to delete a plantskola
const handleDelete = async (id: number) => {
  const plantskola = unverifiedPlantskolor.value?.find((p) => p.id === id);
  if (plantskola) {
    selectedPlantskola.value = plantskola;
    isDeleteModalOpen.value = true;
  }
};

// Confirm verification/unverification
const confirmVerification = async () => {
  if (!selectedPlantskola.value) return;

  const isVerifying = actionType.value === 'verify';
  const { error } = await (supabase as any)
    .from('plantskolor')
    .update({ verified: isVerifying })
    .eq('id', selectedPlantskola.value.id);

  if (error) {
    toast.add({
      title: 'Fel',
      description: `Kunde inte ${isVerifying ? 'verifiera' : 'överifiera'}.`,
    });
  } else {
    toast.add({
      title: isVerifying ? 'Verifierad' : 'Överifierad',
      description: `Plantskolan är nu ${isVerifying ? 'verifierad' : 'överifierad'}.`,
    });
    refresh(); // Refresh the async data
  }

  isVerifyModalOpen.value = false;
  selectedPlantskola.value = null;
};

// Confirm deletion
const confirmDeletion = async () => {
  if (!selectedPlantskola.value) return;

  const { error } = await supabase
    .from('plantskolor')
    .delete()
    .eq('id', selectedPlantskola.value.id);

  if (error) {
    toast.add({ title: 'Fel', description: 'Kunde inte ta bort.' });
  } else {
    toast.add({ title: 'Borttagen', description: 'Plantskolan har tagits bort.' });
    refresh(); // Refresh the async data
  }

  isDeleteModalOpen.value = false;
  selectedPlantskola.value = null;
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
            <UBadge v-if="plantskola.postorder" color="primary" variant="soft" size="sm">
              Postorder
            </UBadge>
            <UBadge v-if="plantskola.on_site" color="primary" variant="soft" size="sm">
              Hämtning på plats
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

    <!-- Verification/Unverification Confirmation Modal -->
    <UModal v-model:open="isVerifyModalOpen">
      <template #content>
        <div class="p-4">
          <h3 class="text-lg font-bold">
            {{ actionType === 'verify' ? 'Verifiera plantskola' : 'Överifiera plantskola' }}
          </h3>
          <div v-if="selectedPlantskola">
            <p class="mb-4">
              Är du säker på att du vill {{ actionType === 'verify' ? 'verifiera' : 'överifiera' }}
              <strong>{{ selectedPlantskola.name }}</strong
              >?
            </p>
          </div>
          <div class="flex justify-end gap-2">
            <UButton variant="ghost" @click="isVerifyModalOpen = false"> Avbryt </UButton>
            <UButton
              :color="actionType === 'verify' ? 'success' : 'warning'"
              @click="confirmVerification"
            >
              {{ actionType === 'verify' ? 'Verifiera' : 'Överifiera' }}
            </UButton>
          </div>
        </div>
      </template>
    </UModal>

    <!-- Delete Confirmation Modal -->
    <UModal v-model:open="isDeleteModalOpen">
      <template #content>
        <div class="p-4">
          <h3 class="text-lg font-semibold text-error">Ta bort plantskola</h3>
          <div v-if="selectedPlantskola">
            <p class="mb-4">
              Är du säker på att du vill ta bort <strong>{{ selectedPlantskola.name }}</strong
              >?
            </p>
            <div class="text-sm text-t-toned mb-4">
              <p><strong>Email:</strong> {{ selectedPlantskola.email }}</p>
              <p><strong>Telefon:</strong> {{ selectedPlantskola.phone }}</p>
              <p><strong>Adress:</strong> {{ selectedPlantskola.adress }}</p>
            </div>
            <div class="bg-error/10 border border-error/20 rounded-md p-3 mb-4">
              <p class="text-sm text-error font-medium">
                ⚠️ Denna åtgärd kan inte ångras. All data kopplad till plantskolan kommer att tas
                bort permanent.
              </p>
            </div>
          </div>
          <div class="flex justify-end gap-2">
            <UButton variant="ghost" @click="isDeleteModalOpen = false"> Avbryt </UButton>
            <UButton color="error" @click="confirmDeletion"> Ta bort </UButton>
          </div>
        </div>
      </template>
    </UModal>
  </div>
</template>

<style></style>
