<script setup lang="ts"></script>

<template>
  <!-- Container with hazard tape background using CSS linear-gradient -->
  <div class="p-4 w-full">
    <div
      class="w-full p-12 md:p-16 border-8 border-info rounded-2xl flex items-center justify-center"
      style="
        background: repeating-linear-gradient(
          45deg,
          transparent,
          transparent 30px,
          var(--ui-info) 30px,
          var(--ui-info) 60px
        );
      "
    >
      <div class="bg-bg p-8 rounded-xl">
        <h1 class="text-info text-4xl md:text-6xl font-black">Work in progress...</h1>
        <p class="mt-2 text-lg text-info">
          Hemsidan är fortfarande under konstruktion.
          <span class="text-lg text-info font-bold">Men kul att se att du är intresserad! :)</span>
        </p>
      </div>
    </div>
  </div>
</template>

<style></style>
