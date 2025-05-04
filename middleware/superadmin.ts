import { useSupabaseUser, useSupabaseClient } from '#imports';
import { useRouter } from 'vue-router';

export default defineNuxtRouteMiddleware(async (to, from) => {
  // Only guard /superadmin routes, but allow /superadmin/login
  if (!to.path.startsWith('/superadmin') || to.path === '/superadmin/login') return;

  const user = useSupabaseUser();
  const supabase = useSupabaseClient();

  // Wait for user to be loaded
  if (!user.value) {
    return navigateTo('/superadmin/login');
  }

  // Check if user is in superadmins table
  const { data } = await supabase.from('superadmins').select('id').eq('user_id', user.value.id).single();
  if (!data) {
    return navigateTo('/superadmin/login?error=unauthorized');
  }
});