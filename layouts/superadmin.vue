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

const navItems = [
  { label: 'Start', to: '/superadmin' },
  { label: 'Bilder', to: '/superadmin/bilder' },
  { label: 'Plantskolor', to: '/superadmin/plantskolor' },
  { label: 'Växter', to: '/superadmin/vaxter' },
];
</script>

<template>
  <NuxtLoadingIndicator color="#76994e" />
  <div class="grid grid-rows-[auto_1fr_auto] min-h-screen w-full">
    <div class="mb-10">
      <div
        class="flex flex-col md:flex-row items-center justify-between gap-4 p-4 bg-bg-elevated border-b border-border"
      >
        <ULink to="/superadmin" class="text-t-regular">
          <h1 class="text-2xl font-bold flex items-center gap-2">
            <span class="bg-primary leading-0 p-1.5 rounded-xl">
              <UIcon name="devicon-plain:bash" size="30" class="text-inverted leading-0" />
            </span>
            Superadmin Panel
          </h1>
        </ULink>
        <div class="flex flex-row gap-4 items-center">
          <UButton color="primary" to="/">Tillbaka</UButton>
          <ColorModeButton />
        </div>
      </div>
      <div class="w-full bg-bg-elevated px-2 border-b border-border flex items-center md:gap-4">
        <ULink
          v-for="item in navItems"
          :key="item.label"
          :to="item.to"
          class="py-2 px-2 hover:bg-bg-accented"
          active-class="bg-primary text-white hover:bg-primary"
        >
          {{ item.label }}
        </ULink>

        <UButton color="error" @click="handleLogout" size="xs" variant="ghost" class="ml-auto p-2"
          >Logga ut</UButton
        >
      </div>
    </div>

    <div class="flex flex-col items-center gap-4">
      <slot />
    </div>

    <!-- Footer -->
    <div
      class="flex flex-col items-center justify-center p-4 bg-bg-elevated border-t border-border"
    >
      <h2 class="text-lg font-semibold mb-2">Superadmin 😛😛😛</h2>
      <div class="text-t-toned text-xs">
        Inloggad som: <span class="font-mono">{{ user?.email }}</span>
      </div>
    </div>
  </div>
</template>
