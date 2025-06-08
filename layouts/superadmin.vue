<script setup lang="ts">
// Use Nuxt composables and Supabase client
const user = useSupabaseUser();
const supabase = useSupabaseClient();
const router = useRouter();
const toast = useToast();

// Logout function for superadmin
const handleLogout = async () => {
  await supabase.auth.signOut();
  toast.add({ title: 'Utloggad', description: 'Du har loggats ut.' });
  router.replace('/superadmin/login');
};
</script>

<template>
  <div class="grid grid-rows-[auto_1fr] min-h-screen w-full">
    <div
      class="flex flex-col md:flex-row items-center justify-between gap-4 mb-10 p-4 bg-bg-elevated"
    >
      <h1 class="text-2xl font-bold flex items-center gap-2">
        <span class="bg-primary leading-0 p-1.5 rounded-xl">
          <UIcon name="devicon-plain:bash" size="30" class="text-inverted leading-0" />
        </span>
        Superadmin Panel
      </h1>
      <div class="flex flex-row gap-4 items-center">
        <div class="text-t-toned">
          Inloggad som: <span class="font-mono">{{ user?.email }}</span>
        </div>
        <UButton color="error" @click="handleLogout" class="">Logga ut</UButton>
        <UButton color="primary" to="/">Tillbaka</UButton>
        <ColorModeButton />
      </div>
    </div>
    <div class="flex flex-col items-center gap-4">
      <slot />
    </div>
  </div>
</template>
