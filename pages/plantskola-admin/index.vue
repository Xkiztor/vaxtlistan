<script setup lang="ts">
import type { Plantskola, Totallager, Facit } from '~/types/supabase-tables';

// Get current user and supabase client
const user = useSupabaseUser();
const supabase = useSupabaseClient();
const router = useRouter();

// Fetch plantskola info for greeting
const { data: plantskola } = await useAsyncData('plantskola', async () => {
  if (!user.value) return null;
  const { data, error } = await supabase
    .from('plantskolor')
    .select()
    .eq('user_id', user.value.id)
    .single();
  if (error || !data) return null;
  return data as Plantskola;
});

definePageMeta({
  layout: 'admin',
  middleware: 'plantskola-admin',
});
</script>

<template>
  <div class="max-w-2xl mx-auto py-10 px-4">
    <!-- Greeting -->
    <h1 class="text-3xl md:text-4xl font-bold mb-6 flex items-center gap-2">
      <span
        class="truncate max-w-full flex-shrink text-ellipsis whitespace-nowrap overflow-hidden"
        style="font-size: clamp(1.5rem, 5vw, 2.5rem)"
      >
        Hej <span class="italic underline font-black">{{ plantskola?.name || 'plantskola' }}</span>
      </span>
      <UIcon
        name="material-symbols:verified-rounded"
        class="text-secondary"
        v-if="plantskola!.verified"
      />
    </h1>
    <!-- Actions -->
    <div class="grid grid-cols-2 gap-4">
      <UButton
        class="w-full grid place-items-center py-4"
        color="neutral"
        variant="subtle"
        size="xl"
        to="/plantskola-admin/lager"
      >
        Lager
      </UButton>
      <UButton
        class="w-full grid place-items-center py-4"
        color="neutral"
        variant="subtle"
        size="xl"
        to="/plantskola-admin/profil"
      >
        Profil
      </UButton>
    </div>
  </div>
</template>

<style scoped>
/* Only use Nuxt UI and Tailwind classes */
</style>
