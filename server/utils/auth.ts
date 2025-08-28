/**
 * Authentication middleware for API routes
 * Validates user authentication and authorization
 */

import type { User } from '@supabase/supabase-js';
import { AuthenticationError, AuthorizationError } from '~/utils/errors';

/**
 * Validates if user is authenticated
 */
export const requireAuth = (user: User | null): User => {
  if (!user) {
    throw new AuthenticationError('Authentication required');
  }
  return user;
};

/**
 * Validates if user is a plantskola admin
 */
export const requirePlantskolaAdmin = async (user: User, supabase: any): Promise<any> => {
  const { data, error } = await supabase
    .from('plantskolor')
    .select('id, verified')
    .eq('user_id', user.id)
    .single();

  if (error || !data) {
    throw new AuthorizationError('Access denied: Not a registered plantskola');
  }

  return data;
};

/**
 * Validates if user is a superadmin
 */
export const requireSuperAdmin = async (user: User, supabase: any): Promise<void> => {
  const { data, error } = await supabase
    .from('superadmins')
    .select('id')
    .eq('user_id', user.id)
    .single();

  if (error || !data) {
    throw new AuthorizationError('Access denied: Superadmin privileges required');
  }
};

/**
 * Rate limiting utility
 * TODO: Implement with Redis or similar for production
 */
interface RateLimit {
  windowMs: number;
  maxRequests: number;
}

const rateLimitStore = new Map<string, { count: number; resetTime: number }>();

export const checkRateLimit = (
  identifier: string,
  limits: RateLimit = { windowMs: 60 * 1000, maxRequests: 10 }
): boolean => {
  const now = Date.now();
  const window = rateLimitStore.get(identifier);

  if (!window || now > window.resetTime) {
    // New window or expired window
    rateLimitStore.set(identifier, {
      count: 1,
      resetTime: now + limits.windowMs
    });
    return true;
  }

  if (window.count >= limits.maxRequests) {
    return false; // Rate limit exceeded
  }

  window.count++;
  return true;
};

/**
 * Get client identifier for rate limiting
 */
export const getClientIdentifier = (event: any): string => {
  // Try to get real IP from headers (if behind proxy)
  const realIP = getHeader(event, 'x-real-ip') || 
                 getHeader(event, 'x-forwarded-for')?.split(',')[0] ||
                 getClientIP(event) || 'unknown';
  
  return realIP || 'unknown';
};
