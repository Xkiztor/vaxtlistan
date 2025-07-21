// composables/useScreen.js
import { ref, onMounted } from 'vue'

export const useScreen = () => {
  const isMobile = ref(false)
  const isTablet = ref(false)
  const isDesktop = ref(false)
  const isLargeDesktop = ref(false)
  const clientReady = ref(false)

  const updateScreen = () => {
    const width = window.innerWidth
    isMobile.value = width <= 768
    isTablet.value = width > 768 && width <= 1024
    isDesktop.value = width > 1024 && width <= 1440
    isLargeDesktop.value = width > 1440
  }

  onMounted(() => {
    updateScreen() // force check on mount
    clientReady.value = true
    window.addEventListener('resize', updateScreen)
  })

  return { isMobile, isTablet, isDesktop, isLargeDesktop, clientReady }
}
