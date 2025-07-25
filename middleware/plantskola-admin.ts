// Middleware to protect plantskola-admin routes
// Redirects to login if not authenticated or not a registered plantskola
import { defineNuxtRouteMiddleware, useSupabaseClient, useSupabaseUser, navigateTo } from '#imports';

export default defineNuxtRouteMiddleware(async (to, from) => {
  const user = useSupabaseUser();
  const supabase = useSupabaseClient();


  // Allow access to login, register and no-plantskola pages
  if (to.path === '/plantskola-admin/login' || 
      to.path === '/plantskola-admin/register' || 
      to.path === '/plantskola-admin/no-plantskola') {
    return;
  }

  // Redirect to login if not authenticated
  if (!user.value) {
    return navigateTo('/plantskola-admin/login');
  }

  // Check if user is a registered plantskola
  const { data, error } = await supabase
    .from('plantskolor')
    .select('id')
    .eq('user_id', user.value.id)
    .single();

  // If user account is not connected to any plantskola, redirect to no-plantskola page
  if (error || !data) {
    return navigateTo('/plantskola-admin/no-plantskola');
  }
});