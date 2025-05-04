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
    :icon="isDark ? 'i-lucide-moon' : 'i-lucide-sun'"
    color="neutral"
    variant="ghost"
    @click="isDark = !isDark"
    class="px-1 py-2"
    >{{ full ? (isDark ? 'Mörkt läge' : 'Ljust läge') : '' }}</UButton
  >
  <!-- </ClientOnly> -->
</template>
