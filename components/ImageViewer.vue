<script setup lang="ts">
defineProps<{
  src: string;
}>();

const emit = defineEmits<{ close: [boolean] }>();
</script>

<template>
  <UModal
    :close="{
      onClick: () => emit('close', false),
      color: 'primary',
      variant: 'outline',
      class: 'rounded-full',
    }"
    class="flex items-center justify-center bg-transparent border-0 shadow-none border-transparent ring-0 ring-transparent"
  >
    <template #content>
      <div
        class="flex items-center justify-center bg-transparent border-0 shadow-none border-transparent"
      >
        <NuxtImg
          :src="src"
          class="max-w-[90vw] max-h-[90vh] object-contain shadow-lg rounded"
          alt="Image"
        />
      </div>
    </template>
  </UModal>
</template>
