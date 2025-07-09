<script setup>
const props = defineProps({
  full: Boolean,
});

const colorMode = useColorMode();

const isDark = computed({
  get() {
    return colorMode.value === 'dark';
  },
  set(_isDark) {
    colorMode.preference = _isDark ? 'dark' : 'light';
  },
});
</script>

<template>
  <!-- <ClientOnly> -->
  <UButton
    :icon="isDark ? 'i-lucide-sun' : 'i-lucide-moon'"
    color="neutral"
    variant="ghost"
    @click="isDark = !isDark"
    class="px-1 py-0"
    >{{ full ? (isDark ? 'Ljust läge' : 'Mörkt läge') : '' }}</UButton
  >
  <!-- </ClientOnly> -->
</template>
