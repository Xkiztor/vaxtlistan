<script setup lang="ts">
const { width, height } = useWindowSize();
const expandSearchScreenWidth = 550; // Width at which search expands

const user = useSupabaseUser();

const menuOpen = ref(false);
const mobileSearchActive = ref(false);

function toggleMenu() {
  menuOpen.value = !menuOpen.value;
}
function closeMenu() {
  menuOpen.value = false;
}
function handleMobileSearchFocus() {
  mobileSearchActive.value = true;
}
function handleMobileSearchBlur() {
  mobileSearchActive.value = false;
}
</script>

<template>
  <div class="min-h-screen flex flex-col">
    <nav
      class="fixed z-40 top-0 left-0 right-0 h-20 has-[.mobile-nav]:h-screen has-[.mobile-nav]:bottom-0 has-[.mobile-nav]:grid grid-rows-[auto_1fr]"
    >
      <div
        class="border-border border-b-1 flex justify-between p-4 bg-bg-elevated h-20"
      >
        <!-- Top part -->
        <transition name="logo-fade">
          <div
            class="flex items-center pr-2 min-[450px]:pr-4 w-48 shrink-0"
            v-if="!mobileSearchActive || width > expandSearchScreenWidth"
          >
            <!-- Logo with transition -->
            <NuxtLink
              to="/"
              class="font-black text-xl sm:text-2xl whitespace-nowrap overflow-hidden"
              >Växtlistan.se</NuxtLink
            >
            <!-- InlineSearch expands on mobile when focused -->
          </div>
        </transition>
        <div
          class="flex items-center gap-4 lg:gap-8 max-md:hidden flex-1 w-max shrink-0 pr-4 xl:pl-8"
        >
          <!-- Navigation links -->
          <!-- <NuxtLink
            to="/for-plantskolor"
            @click="closeMenu"
            class="shrink-0 w-max"
            active-class="text-primary font-bold underline router-link-active"
          >
            <span class="max-lg:hidden">Information för plantskolor</span>
            <span class="lg:hidden">Info för plantskolor</span>
          </NuxtLink>
          <NuxtLink
            to="/om-oss"
            @click="closeMenu"
            class="shrink-0 w-max"
            active-class="text-primary font-bold underline router-link-active"
          >
            Om växtlistan
          </NuxtLink> -->
          <NuxtLink
            to="/vaxt/s"
            @click="closeMenu"
            class="shrink-0 w-max"
            active-class="text-primary font-bold underline router-link-active"
          >
            Alla växter
          </NuxtLink>

          <!-- <UPopover
            class="shrink-0 w-max flex items-center cursor-pointer gap-1"
            :content="{
              align: 'center',
              side: 'bottom',
              sideOffset: 8,
            }"
            mode="hover"
            :open-delay="0"
            :close-delay="0"
            :ui="{ content: 'bg-bg-elevated p-4 flex flex-col gap-4' }"
          >
            <span class=""
              >Plantskolor
              <UIcon
                name="material-symbols:keyboard-arrow-down-rounded"
                class="text-xl"
              ></UIcon>
            </span>
            <template #content>
              <NuxtLink
                to="/plantskolor"
                @click="closeMenu"
                class="shrink-0 w-max"
                active-class="text-primary font-bold underline router-link-active"
              >
                Alla plantskolor
              </NuxtLink>
              <NuxtLink
                to="/for-plantskolor"
                @click="closeMenu"
                class="shrink-0 w-max"
                active-class="text-primary font-bold underline router-link-active"
              >
                Information för plantskolor
              </NuxtLink>
            </template>
          </UPopover> -->
          <UNavigationMenu
            :items="[
              {
                label: 'Plantskolor',
                activeClass:
                  'text-primary font-bold underline router-link-active',
                children: [
                  {
                    label: 'Alla plantskolor',
                    to: '/plantskolor',
                    activeClass:
                      'text-primary font-bold underline router-link-active',
                  },
                  {
                    label: 'Information för plantskolor',
                    to: '/for-plantskolor',
                    activeClass:
                      'text-primary font-bold underline router-link-active',
                  },
                ],
              },
            ]"
            :ui="{
              link: 'text-t-regular text-base font-normal',
              viewport: 'w-fit sm:w-fit overflow-visible bg-bg-elevated',
              content: 'static',
              childLink: 'bg-transparent',
            }"
            content-orientation="vertical"
            highlight
          />
        </div>
        <div
          class="items-center flex-row flex gap-2 min-[450px]:gap-4 justify-end max-md:w-full max-md:grow"
        >
          <!-- Search bar using InlineSearch component -->
          <InlineSearch
            mode="navbar"
            class="grow shrink basis-0"
            @select="handleMobileSearchFocus"
            @deslect="handleMobileSearchBlur"
          />

          <!-- Login button using Nuxt UI UButton -->
          <UButton
            class="max-md:hidden w-max shrink-0"
            size="xl"
            to="/plantskola-admin/login"
          >
            <span v-if="user">Adminsidan </span>
            <span v-else>Plantskola - Login</span></UButton
          >
          <div
            class="max-md:hidden shrink-0 h-full flex flex-col justify-center"
          >
            <ColorModeButton />
          </div>
          <UButton
            v-if="menuOpen"
            icon="i-material-symbols-close-rounded"
            variant="ghost"
            class="max-md:hidden flex items-center justify-center p-0 text-regular"
            size="xl"
            :ui="{ leadingIcon: 'scale-125' }"
            @click="toggleMenu"
          />
          <!-- Hamburger/Close button for mobile with 180deg rotate transition -->
          <transition name="rotate-180" class="md:hidden">
            <div v-if="!menuOpen">
              <UButton
                key="hamburger"
                icon="i-material-symbols-menu-rounded"
                variant="ghost"
                color="neutral"
                class="md:hidden flex items-center justify-center p-0 text-regular"
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
                color="neutral"
                class="md:hidden flex items-center justify-center p-0 text-regular"
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
          class="mobile-nav p-4 bg-bg-elevated flex flex-col gap-4 text-xl"
        >
          <div class="py-2 flex flex-col gap-4">
            <!-- Navigation links -->
            <NuxtLink
              to="/"
              @click="closeMenu"
              class="block"
              active-class="text-primary font-bold underline router-link-active"
            >
              Startsidan
            </NuxtLink>
            <NuxtLink
              to="/vaxt/s"
              @click="closeMenu"
              class="block"
              active-class="text-primary font-bold underline router-link-active"
            >
              Alla växter
            </NuxtLink>
            <NuxtLink
              to="/for-plantskolor"
              @click="closeMenu"
              class="block"
              active-class="text-primary font-bold underline router-link-active"
            >
              Information för plantskolor
            </NuxtLink>
            <NuxtLink
              to="/om-oss"
              @click="closeMenu"
              class="block"
              active-class="text-primary font-bold underline router-link-active"
            >
              Om växtlistan
            </NuxtLink>
          </div>
          <div class="flex flex-col gap-4 border-t-1 border-border pt-4">
            <UButton
              class="w-full"
              size="xl"
              @click="closeMenu"
              to="/plantskola-admin/login"
            >
              <span v-if="user">Till Adminsidan</span>
              <span v-else>Plantskola - Login</span>
            </UButton>
            <ColorModeButton full />
          </div>
        </div>
      </transition>
    </nav>

    <!-- Main content area -->
    <div class="page pt-20 flex-1">
      <slot />
    </div>
    <!--  -->

    <!-- Footer -->
    <footer
      class="mt-4 flex flex-col items-center justify-center p-4 bg-bg-elevated border-t border-border"
    >
      <div class="flex-1">
        <div
          class="flex flex-col md:grid grid-cols-[auto_auto] max-md:items-center gap-2 md:gap-8"
        >
          <div
            class="flex gap-4 md:gap-2 md:flex-col md:col-[2] text-sm underline"
          >
            <NuxtLink
              to="/om-oss"
              class="text-muted hover:text-primary transition-colors"
            >
              Om Växtlistan
            </NuxtLink>
            <NuxtLink
              to="/for-plantskolor"
              class="text-muted hover:text-primary transition-colors"
            >
              Information för plantskolor
            </NuxtLink>
            <NuxtLink
              to="/plantskola-admin/login"
              class="text-muted hover:text-primary transition-colors"
            >
              Plantskola - Login
            </NuxtLink>
          </div>
          <div class="md:col-[1] md:row-[1]">
            <div class="max-md:mt-2 text-sm text-muted max-md:text-center">
              Växtlistan.se är en samlad plats för Sveriges plantskolor och
              växtintresserade.<br />
            </div>
            <div class="mt-2 text-sm text-muted max-md:text-center">
              Kontakta oss på
              <a
                href="mailto:kontakt@vaxtlistan.se"
                class="text-primary underline"
                >kontakt@vaxtlistan.se</a
              >
            </div>
          </div>
        </div>
      </div>
      <div class="text-xs text-muted text-center">
        &copy; {{ new Date().getFullYear() }} Växtlistan.se
      </div>
    </footer>
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

/* Search expand transition */
.search-expand-enter-active,
.search-expand-leave-active {
  transition: max-width 0.35s cubic-bezier(0.4, 0, 0.2, 1),
    padding 0.35s cubic-bezier(0.4, 0, 0.2, 1);
}
.search-expand-enter-from,
.search-expand-leave-to {
  max-width: 16rem; /* max-w-xs */
  padding-left: 1rem;
  padding-right: 1rem;
}
.search-expand-enter-to,
.search-expand-leave-from {
  max-width: 42rem; /* max-w-2xl */
  padding-left: 1.5rem;
  padding-right: 1.5rem;
}

.logo-fade-enter-active,
.logo-fade-leave-active {
  transition: all 0.2s ease-in-out;
}
.logo-fade-enter-from,
.logo-fade-leave-to {
  opacity: 0.7;
  width: 0;
  padding: 0;
}

.logo-fade-enter-to,
.logo-fade-leave-from {
  /* opacity: 1; */
  /* width: 11rem; */
}
</style>
