// Middleware to protect plantskola-admin routes
// Redirects to login if not authenticated or not a registered plantskola
import { defineNuxtRouteMiddleware, useSupabaseClient, useSupabaseUser, navigateTo } from '#imports';

export default defineNuxtRouteMiddleware(async (to, from) => {
  const user = useSupabaseUser();
  const supabase = useSupabaseClient();


  // Allow access to login and register pages if not logged in
  if (to.path === '/plantskola-admin/login' || to.path === '/plantskola-admin/register') {
    return;
  }

  if (!user.value) {
    return navigateTo('/plantskola-admin/login');
  }
  // Check if user is a registered plantskola
  const { data, error } = await supabase.from('plantskolor').select('id').eq('user_id', user.value.id).single();
  if (error || !data) {
    return navigateTo('/plantskola-admin/login');
  }
});
