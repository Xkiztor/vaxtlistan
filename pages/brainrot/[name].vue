<template>
  <div class="details-page">
    <img :src="currentItem.image" alt="" />
    <h1 class="page-title">{{ currentItem.title }}</h1>
    <p>{{ currentItem.description }}</p>
  </div>
</template>

<script setup>
definePageMeta({
  layout: "empty",
});

const route = useRoute();
const pageTitle = computed(() => `Brainrot: ${route.params.name}`);

const brainrotItems = [
  {
    id: 1,
    title: "Tralalero Tralala",
    description: "Väldigt cool haj. Snygga blåa skor!",
    image:
      "https://brushme.com/static/uploads/media/products/product_thumb_12925_68348a339f0223.48585529.jpg",
  },
  {
    id: 2,
    title: "Ballerina Cappuccina",
    description: "",
    image:
      "https://brushme.com/static/uploads/media/products/product_thumb_12930_68348a3ee51580.32373640.jpg",
  },
  {
    id: 3,
    title: "Tung Tung Tung Sahur",
    description: "tung ".repeat(500).trim(),
    image: "https://i.redd.it/t20nfsv8guwe1.jpeg",
  },
  {
    id: 4,
    title: "Bombardino krokodilo",
    description: "",
    image:
      "https://brushmeworld.com/cdn/shop/files/2_4004c186-b51a-4488-8125-7de4fd984528.jpg?v=1746642987",
  },
];

const currentItem = computed(() => {
  return brainrotItems.find((item) => item.title === route.params.name);
});
</script>

<style scoped>
.details-page {
  padding: 1rem;
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  align-items: center;
}

.details-page .page-title {
  font-size: 3rem;
  font-weight: 900;
  max-width: fit-content;
  line-height: 1;
  margin-top: 20px;
  margin-bottom: 10px;
}

.details-page img {
  width: 100%;
  object-fit: cover;
  height: auto;
  max-height: 20rem;
  border-radius: 10px;
}
</style>
