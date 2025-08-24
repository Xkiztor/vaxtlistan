<script setup lang="ts">
const props = defineProps<{
  group: {
    nursery: {
      plantskola_id: number;
      nursery_name: string;
      nursery_address: string | null;
      nursery_on_site: boolean;
      nursery_postorder: boolean;
      nursery_email: string | null;
      nursery_phone: string | null;
      nursery_url: string | null;
    };
    plants: Array<{
      id: number;
      stock: number;
      price: number | null;
      pot: string | null;
      height: number | null;
      name_by_plantskola: string | null;
      comment_by_plantskola: string | null;
      last_edited: string; // ISO date string
    }>;
  };
}>();

const expanded = ref(false);

// Function to copy text to clipboard
const copyToClipboard = async (text: string) => {
  try {
    await navigator.clipboard.writeText(text);
    // Show success notification
    const toast = useToast();
    toast.add({
      title: 'Kopierat!',
      description: `${text} har kopierats till urklipp`,
      color: 'success',
    });
  } catch (error) {
    console.error('Failed to copy to clipboard:', error);
    // Fallback for older browsers
    const textArea = document.createElement('textarea');
    textArea.value = text;
    document.body.appendChild(textArea);
    textArea.select();
    document.execCommand('copy');
    document.body.removeChild(textArea);

    const toast = useToast();
    toast.add({
      title: 'Kopierat!',
      description: `${text} har kopierats till urklipp`,
      color: 'success',
    });
  }
};

// Function to format date for display
const formatDate = (dateString: string) => {
  return new Date(dateString).toLocaleDateString('sv-SE', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });
};

// Height transition hooks for expand/collapse
function beforeEnter(el: Element) {
  const elH = el as HTMLElement;
  elH.style.height = '0';
  elH.style.opacity = '0';
  elH.style.overflow = 'hidden';
}
function enter(el: Element, done: () => void) {
  const elH = el as HTMLElement;
  elH.style.transition = 'height 0.25s ease, opacity 0.25s ease';
  elH.style.height = elH.scrollHeight + 'px';
  elH.style.opacity = '1';
  elH.addEventListener('transitionend', function handler(e) {
    if (e.propertyName === 'height') {
      elH.removeEventListener('transitionend', handler);
      elH.style.height = '';
      elH.style.overflow = '';
      elH.style.transition = '';
      done();
    }
  });
}
function afterEnter(el: Element) {
  const elH = el as HTMLElement;
  elH.style.height = '';
  elH.style.overflow = '';
  elH.style.transition = '';
}
function beforeLeave(el: Element) {
  const elH = el as HTMLElement;
  elH.style.height = elH.scrollHeight + 'px';
  elH.style.opacity = '1';
  elH.style.overflow = 'hidden';
}
function leave(el: Element, done: () => void) {
  const elH = el as HTMLElement;
  void elH.offsetHeight;
  elH.style.transition = 'height 0.25s ease, opacity 0.25s ease';
  elH.style.height = '0';
  elH.style.opacity = '0';
  elH.addEventListener('transitionend', function handler(e) {
    if (e.propertyName === 'height') {
      elH.removeEventListener('transitionend', handler);
      elH.style.height = '';
      elH.style.overflow = '';
      elH.style.transition = '';
      done();
    }
  });
}
function afterLeave(el: Element) {
  const elH = el as HTMLElement;
  elH.style.height = '';
  elH.style.overflow = '';
  elH.style.transition = '';
}
</script>

<template>
  <div class="mb-8">
    <!-- Nursery Header -->
    <header class="flex flex-col sm:flex-row sm:items-start gap-2 mb-3">
      <div class="flex-1">
        <ULink
          :to="`/plantskola/${group.nursery.plantskola_id}`"
          class="text-xl text-t-regular font-bold hover:opacity-80"
          itemprop="seller"
          itemscope
          itemtype="https://schema.org/Organization"
        >
          <span itemprop="name">{{ group.nursery.nursery_name }}</span>
        </ULink>
        <p
          v-if="group.nursery.nursery_address && group.nursery.nursery_on_site"
          class="text-sm text-t-toned flex items-center"
          itemprop="address"
        >
          <!-- <UIcon name="i-heroicons-map-pin" class="mr-1" /> -->
          <span class="mr-1">Hämtning på plats i</span>
          <span itemprop="streetAddress" class="font-bold">{{
            group.nursery.nursery_address?.split(' ').slice(-1)[0]
          }}</span>
        </p>
        <p v-else-if="group.nursery.nursery_on_site" class="text-sm text-t-toned">
          Hämtning på plats
        </p>
        <UBadge
          color="primary"
          variant="soft"
          size="xs"
          v-if="group.nursery.nursery_postorder"
          class="text-sm flex items-center w-fit"
        >
          <UIcon name="material-symbols:delivery-truck-speed-outline-rounded" class="text-base" />
          Postorder
        </UBadge>
      </div>
    </header>
    <!-- Multiple plant details for this nursery -->
    <div class="flex flex-col gap-4">
      <Transition
        @before-enter="beforeEnter"
        @enter="enter"
        @after-enter="afterEnter"
        @before-leave="beforeLeave"
        @leave="leave"
        @after-leave="afterLeave"
      >
        <div v-if="group.plants.length === 1 || expanded" class="flex flex-col gap-4">
          <div
            v-for="stock in group.plants.sort((a, b) => a.price! - b.price!)"
            :key="stock.id"
            class="bg-bg-elevated px-4 py-3 rounded-xl flex justify-between"
          >
            <div class="grow">
              <!-- Plant specifications -->
              <div
                class="flex items-center gap-4 flex-wrap text-sm grow"
                v-if="stock.pot || stock.height"
              >
                <div v-if="stock.pot" class="flex items-center flex-col">
                  Kruka:
                  <span class="font-semibold text-base">{{ stock.pot }}</span>
                </div>
                <div v-if="stock.height" class="flex items-center flex-col">
                  Höjd:
                  <span class="text-base">
                    <span class="font-semibold">{{ stock.height }}</span>
                    cm
                  </span>
                </div>
              </div>
              <!-- Nursery's plant name (if different) -->
              <!-- <div
              v-if="stock.name_by_plantskola && stock.name_by_plantskola !== plant?.name"
              class="text-sm"
            >
              <span class="font-medium">Plantskolans namn:</span>
              <span class="italic ml-1">{{ stock.name_by_plantskola }}</span>
            </div> -->
              <!-- Nursery's comment -->
              <div v-if="stock.comment_by_plantskola" class="text-sm mt-1 flex items-center">
                <!-- <span class="font-medium">Kommentar:</span> -->
                <Icon name="material-symbols:info-outline-rounded" class="text-base text-primary" />
                <span class="ml-1">{{ stock.comment_by_plantskola }}</span>
              </div>
            </div>

            <!-- Stock and Price -->
            <div class="flex items-end flex-col leading-none min-w-fit justify-center">
              <div v-if="stock.price" class="flex items-center gap-2">
                <span class="font-medium text-lg md:text-xl">
                  <span itemprop="price" :content="stock.price" class="font-bold">{{
                    stock.price
                  }}</span>
                  <span itemprop="priceCurrency" content="SEK"> kr</span>
                </span>
              </div>
              <div class="" v-if="stock.stock > 0">
                <span
                  class="text-t-toned text-sm"
                  itemprop="availability"
                  content="https://schema.org/InStock"
                >
                  <span class="font-bold">{{ stock.stock }}</span> st i lager
                </span>
              </div>
            </div>
          </div>
        </div>
      </Transition>
      <div v-if="group.plants.length > 1" class="" :class="{ 'mt-4': expanded }">
        <div>
          <!-- Summary of all plants: shows price range, total stock, and number of alternatives -->
          <div
            class="flex flex-row items-center gap-2 mb-2 justify-between bg-bg-elevated px-4 py-3 rounded-xl"
            v-if="!expanded"
          >
            <div>
              <!-- Number of alternatives -->
              <div class="flex items-center gap-1">
                <span class="font-bold md:text-2xl">{{ group.plants.length }}</span>
                <span>olika storlekar</span>
              </div>
              <!-- Total stock -->
              <div class="flex items-center gap-1 text-t-toned text-sm md:hidden">
                <span class="font-medium">Totalt i lager:</span>
                <span class="font-bold">
                  {{ group.plants.reduce((sum, plant) => sum + (plant.stock || 0), 0) }}
                </span>
                st
              </div>
            </div>
            <!-- Price range -->
            <div>
              <div
                v-if="group.plants.some((p) => p.price !== null)"
                class="flex items-center gap-1"
              >
                <span class="font-bold md:text-xl">
                  {{
                    (() => {
                      const prices = group.plants
                        .map((p) => p.price)
                        .filter((p): p is number => p !== null)
                        .sort((a, b) => a - b);
                      if (prices.length === 0) return '–';
                      if (prices[0] === prices[prices.length - 1]) return `${prices[0]} kr`;
                      return `${prices[0]} - ${prices[prices.length - 1]} kr`;
                    })()
                  }}
                </span>
              </div>
              <!-- Total stock -->
              <div class="flex items-center gap-1 text-t-toned text-sm max-md:hidden">
                <span class="font-medium">Totalt i lager:</span>
                <span class="font-bold">
                  {{ group.plants.reduce((sum, plant) => sum + (plant.stock || 0), 0) }}
                </span>
                st
              </div>
            </div>
          </div>
        </div>
        <UButton
          size="md"
          variant="ghost"
          color="neutral"
          class="p-0 hover:opacity-60 hover:bg-transparent transition-all duration-200 expand-button"
          @click="expanded = !expanded"
          :icon="expanded ? 'i-heroicons-chevron-up-20-solid' : 'i-heroicons-chevron-down-20-solid'"
          >{{ expanded ? 'Dölj' : 'Visa alla' }}</UButton
        >
      </div>
    </div>
    <!-- Contact Information -->
    <footer
      v-if="false"
      class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2 mt-4 pt-3 border-t border-border"
    >
      <div class="flex items-center gap-3 flex-wrap">
        <!-- Email dropdown -->
        <UDropdownMenu
          v-if="group.nursery.nursery_email"
          :items="[
            [
              {
                label: 'Kopiera e-post',
                icon: 'i-heroicons-clipboard-document',
                onSelect: () => copyToClipboard(group.nursery.nursery_email || ''),
              },
            ],
            [
              {
                label: 'Skicka e-post',
                icon: 'i-heroicons-envelope',
                onSelect: () =>
                  navigateTo(`mailto:${group.nursery.nursery_email}`, {
                    external: true,
                  }),
              },
            ],
          ]"
        >
          <UButton
            icon="i-heroicons-envelope"
            color="primary"
            variant="outline"
            size="sm"
            trailing-icon="i-heroicons-chevron-down-20-solid"
          >
            E-post
          </UButton>
        </UDropdownMenu>
        <!-- Phone dropdown -->
        <UDropdownMenu
          v-if="group.nursery.nursery_phone"
          :items="[
            [
              {
                label: 'Kopiera telefonnummer',
                icon: 'i-heroicons-clipboard-document',
                onSelect: () => copyToClipboard(group.nursery.nursery_phone || ''),
              },
            ],
            [
              {
                label: 'Ring upp',
                icon: 'i-heroicons-phone',
                onSelect: () =>
                  navigateTo(`tel:${group.nursery.nursery_phone}`, {
                    external: true,
                  }),
              },
            ],
          ]"
        >
          <UButton
            icon="i-heroicons-phone"
            color="primary"
            variant="outline"
            size="sm"
            trailing-icon="i-heroicons-chevron-down-20-solid"
          >
            {{ group.nursery.nursery_phone }}
          </UButton>
        </UDropdownMenu>
        <UButton
          v-if="group.nursery.nursery_url"
          :href="group.nursery.nursery_url || undefined"
          target="_blank"
          rel="noopener noreferrer"
          icon="i-heroicons-globe-alt"
          color="primary"
          variant="outline"
          size="sm"
        >
          Besök webbsida
        </UButton>
      </div>
      <!-- Last updated info: show the latest last_edited among all plants for this nursery -->
      <div class="text-xs text-t-muted self-start sm:self-center">
        Uppdaterat
        {{
          formatDate(
            group.plants.reduce(
              (latest, s) => (s.last_edited > latest ? s.last_edited : latest),
              group.plants[0]?.last_edited || ''
            )
          )
        }}
      </div>
    </footer>
  </div>
</template>

<style scoped>
.expand-button {
  transform-origin: center;
}
.expand-button:hover {
  transform: scale(1.05);
}
.expand-button:active {
  transform: scale(0.95);
}
</style>
