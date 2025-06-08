<script setup lang="ts">
const user = useSupabaseUser();
const supabase = useSupabaseClient();
const router = useRouter();
const toast = useToast();

// Fetch the current plantskola for the logged-in user using useAsyncData
const { data: plantskola } = await useAsyncData('plantskola', async () => {
  const { data, error } = await supabase
    .from('plantskolor')
    .select('name')
    .eq('user_id', user.value.id)
    .single();
  if (error || !data) return null;
  return data;
});

// Logout function for admin
const handleLogout = async () => {
  await supabase.auth.signOut();
  toast.add({ title: 'Utloggad', description: 'Du har loggats ut.' });
  router.replace('/plantskola-admin/login');
};

const menuOpen = ref(false);
function toggleMenu() {
  menuOpen.value = !menuOpen.value;
}
function closeMenu() {
  menuOpen.value = false;
}
</script>

<template>
  <div>
    <nav
      class="fixed z-40 top-0 left-0 right-0 h-20 has-[.mobile-nav]:h-screen has-[.mobile-nav]:bottom-0 has-[.mobile-nav]:grid grid-rows-[auto_1fr]"
    >
      <div class="border-border border-b-1 flex gap-6 justify-between p-4 bg-bg-elevated h-20">
        <!-- Top part -->
        <div class="flex gap-6 items-center">
          <NuxtLink to="/" class="font-black text-2xl">Växtlistan.se</NuxtLink>
          <div class="flex gap-4 items-center">
            <NuxtLink
              to="/plantskola-admin"
              class="font-medium hover:underline max-md:hidden"
              active-class="text-primary font-bold underline router-link-active"
              >Dashboard</NuxtLink
            >
            <NuxtLink
              to="/plantskola-admin/lager"
              class="font-medium hover:underline max-md:hidden"
              active-class="text-primary font-bold underline router-link-active"
              >Lager</NuxtLink
            >
            <NuxtLink
              to="/plantskola-admin/profil"
              class="font-medium hover:underline max-md:hidden"
              active-class="text-primary font-bold underline router-link-active"
              >Profil</NuxtLink
            >
          </div>
        </div>
        <div class="items-center flex-row flex gap-2">
          <div class="max-md:hidden"><ColorModeButton /></div>
          <UButton color="error" @click="handleLogout" class="max-md:hidden">Logga ut</UButton>
          <!-- Hamburger/Close button for mobile -->
          <transition name="rotate-180">
            <div v-if="!menuOpen">
              <UButton
                key="hamburger"
                icon="i-material-symbols-menu-rounded"
                variant="ghost"
                class="md:hidden flex items-center justify-center p-2 text-regular"
                size="xl"
                :ui="{ leadingIcon: 'scale-125' }"
                @click="toggleMenu"
                aria-label="Open menu"
              />
            </div>
            <div v-else>
              <UButton
                key="close"
                icon="i-material-symbols-close-rounded"
                variant="ghost"
                class="md:hidden flex items-center justify-center p-2 text-regular"
                size="xl"
                :ui="{ leadingIcon: 'scale-125' }"
                @click="toggleMenu"
                aria-label="Close menu"
              />
            </div>
          </transition>
        </div>
      </div>
      <!-- Mobile menu overlay (bottom part) -->
      <transition name="fade">
        <div
          v-if="menuOpen"
          class="mobile-nav p-4 bg-bg-elevated flex flex-col text-2xl justify-between"
        >
          <div class="flex flex-col gap-4">
            <NuxtLink
              to="/plantskola-admin"
              @click="closeMenu"
              class="block"
              active-class="text-primary font-bold underline router-link-active"
              >Översikt</NuxtLink
            >
            <NuxtLink
              to="/plantskola-admin/lager"
              @click="closeMenu"
              class="block"
              active-class="text-primary font-bold underline router-link-active"
              >Lager</NuxtLink
            >
            <NuxtLink
              to="/plantskola-admin/profil"
              @click="closeMenu"
              class="block"
              active-class="text-primary font-bold underline router-link-active"
              >Profil</NuxtLink
            >
          </div>
          <div class="flex flex-col gap-4 border-t-1 border-border pt-4 mt-4">
            <ColorModeButton full />
            <UButton color="error" class="w-full" size="xl" @click="handleLogout">Logga ut</UButton>
          </div>
        </div>
      </transition>
    </nav>
    <div class="page pt-20">
      <slot />
    </div>
  </div>
</template>

<style>
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.2s ease-in-out;
}
.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}

.rotate-180-enter-active,
.rotate-180-leave-active {
  transition: transform 0.3s cubic-bezier(0.4, 0, 0.2, 1);
}
.rotate-180-enter-from,
.rotate-180-leave-to {
  position: absolute;
  opacity: 0;
  transform: rotate(90deg);
}
.rotate-180-enter-to,
.rotate-180-leave-from {
  transform: rotate(0deg);
}
</style>
