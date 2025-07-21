<template>
  <div class="brainrot-page">
    <h1 class="title">Brainrot</h1>
    <p class="description">En sida från Ohio.</p>
    <!-- <div class="buttons">
      <button @click="toggleTung" class="tung">
        {{ showTung ? "Dölj tung tung" : "Visa tung tung" }}
      </button>
      <button @click="toggleTralalero" class="tralalero">
        {{ showTralalero ? "Dölj tralalero" : "Visa tralalero" }}
      </button>
      <button @click="toggleCappuccino" class="cappuccino">
        {{ showCappuccino ? "Dölj cappuccino" : "Visa cappuccino" }}
      </button>
    </div> -->
    <img v-if="showTung" src="https://i.redd.it/t20nfsv8guwe1.jpeg" alt="" />
    <img
      v-if="showTralalero"
      src="https://brushme.com/static/uploads/media/products/product_thumb_12925_68348a339f0223.48585529.jpg"
      alt=""
    />
    <img
      v-if="showCappuccino"
      src="https://brushme.com/static/uploads/media/products/product_thumb_12930_68348a3ee51580.32373640.jpg"
      alt=""
    />
    <div class="search">
      <input type="text" name="" id="" v-model="sok" placeholder="Sök..." />
    </div>
    <div class="results">
      <nuxt-link
        v-for="item in filteredItems"
        :key="item.id"
        :to="`/brainrot/${item.title}`"
        class="brainrot-item"
      >
        <img :src="item.image" alt="" />
        <h2>{{ item.title }}</h2>
        <!-- <p>{{ item.description }}</p> -->
      </nuxt-link>
    </div>
  </div>
</template>

<script setup>
definePageMeta({
  layout: "empty",
});
const showTung = ref(false);
const showTralalero = ref(false);
const showCappuccino = ref(false);

function toggleTung() {
  if (showTung.value === false) {
    showTralalero.value = false;
    showCappuccino.value = false;
  }
  showTung.value = !showTung.value;
}

function toggleTralalero() {
  showTralalero.value = !showTralalero.value;
  if (showTralalero.value) {
    showTung.value = false;
    showCappuccino.value = false;
  }
}

function toggleCappuccino() {
  showCappuccino.value = !showCappuccino.value;
  if (showCappuccino.value) {
    showTung.value = false;
    showTralalero.value = false;
  }
}

const sok = ref("");

const brainrotItems = [
  {
    id: 1,
    title: "Tralalero Tralala",
    description: "",
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
    description: "",
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

const filteredItems = computed(() => {
  if (!sok.value) return [];
  return brainrotItems.filter((item) =>
    item.title.toLowerCase().includes(sok.value.toLowerCase())
  );
});
</script>

<style>
.brainrot-page {
  padding: 1rem;
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  align-items: center;
}

.brainrot-page .title {
  font-size: 10rem;
  font-weight: 900;
  color: transparent;
  background-image: url("https://i.ytimg.com/vi/3gmogp5-xXA/hq720.jpg?sqp=-oaymwEhCK4FEIIDSFryq4qpAxMIARUAAAAAGAElAADIQj0AgKJD&rs=AOn4CLBswJf3RFSuaR28EXqpaxf_XV6ZQg");
  background-size: cover;
  background-position: center;
  -webkit-background-clip: text;
  background-clip: text;
  max-width: fit-content;
  line-height: 1;
  margin-top: 20px;
}

.brainrot-page .description {
  font-size: 1.5rem;
  font-weight: 700;
  color: #404040;
}

.brainrot-page img {
  max-width: 500px;
  height: auto;
  margin-top: 20px;
}

.brainrot-page button {
  padding: 10px 20px;
  font-size: 1rem;
  color: #000000;
  background-color: #d5d5d5;
  border: none;
  border-radius: 5px;
  cursor: pointer;
}

button.tung {
  background-color: #915d3e;
  color: #fff;
}
button.tralalero {
  background-color: #2384c1;
  color: #fff;
}
button.cappuccino {
  background-color: #ffbfdb;
}

.brainrot-page .buttons {
  display: flex;
  gap: 10px;
  margin-top: 20px;
}

.search {
  width: 100%;
  padding-top: 1rem;
  /* margin-top: 1rem; */
  /* border-top: #ccc solid 1px; */
  padding-bottom: 1rem;
  margin-bottom: 1rem;
  border-bottom: #ccc solid 1px;
  display: flex;
  justify-content: center;
}

.search input {
  padding: 10px;
  font-size: 1rem;
  border: 1px solid #ccc;
  border-radius: 5px;
  width: 300px;
}

.results {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr;
  gap: 2rem 3rem;
}

.brainrot-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  border: #ccc solid 1px;
  padding: 1rem;
  border-radius: 1rem;
}
.brainrot-item img {
  width: 100%;
  object-fit: cover;
  height: auto;
  border-radius: 10px;
}
.brainrot-item h2 {
  font-size: 1.5rem;
  margin: 10px 0;
}
</style>
