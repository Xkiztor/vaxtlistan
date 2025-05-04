import { defineNuxtRouteMiddleware, useSupabaseUser, navigateTo } from '#imports';

export default defineNuxtRouteMiddleware(() => {
  const user = useSupabaseUser();
  if (user.value) {
    return navigateTo('/plantskola-admin');
  }
});
