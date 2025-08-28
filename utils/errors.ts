/**
 * Custom error types for better error handling and debugging
 * Provides structured error information for different error scenarios
 */

export enum ErrorCode {
  // Database errors
  DATABASE_CONNECTION_ERROR = 'DATABASE_CONNECTION_ERROR',
  DATABASE_QUERY_ERROR = 'DATABASE_QUERY_ERROR',
  DATABASE_VALIDATION_ERROR = 'DATABASE_VALIDATION_ERROR',
  
  // Authentication errors
  AUTHENTICATION_REQUIRED = 'AUTHENTICATION_REQUIRED',
  AUTHORIZATION_FAILED = 'AUTHORIZATION_FAILED',
  INVALID_CREDENTIALS = 'INVALID_CREDENTIALS',
  
  // Validation errors
  VALIDATION_ERROR = 'VALIDATION_ERROR',
  INVALID_INPUT = 'INVALID_INPUT',
  MISSING_REQUIRED_FIELD = 'MISSING_REQUIRED_FIELD',
  
  // External service errors
  SUPABASE_ERROR = 'SUPABASE_ERROR',
  CLOUDINARY_ERROR = 'CLOUDINARY_ERROR',
  EXTERNAL_API_ERROR = 'EXTERNAL_API_ERROR',
  
  // Application errors
  RESOURCE_NOT_FOUND = 'RESOURCE_NOT_FOUND',
  RATE_LIMIT_EXCEEDED = 'RATE_LIMIT_EXCEEDED',
  INTERNAL_SERVER_ERROR = 'INTERNAL_SERVER_ERROR',
}

export interface ErrorDetails {
  code: ErrorCode;
  message: string;
  statusCode: number;
  details?: Record<string, any>;
  cause?: Error;
}

/**
 * Base application error class
 */
export class AppError extends Error {
  public readonly code: ErrorCode;
  public readonly statusCode: number;
  public readonly details?: Record<string, any>;
  public readonly errorCause?: Error;

  constructor(errorDetails: ErrorDetails) {
    super(errorDetails.message);
    this.name = 'AppError';
    this.code = errorDetails.code;
    this.statusCode = errorDetails.statusCode;
    this.details = errorDetails.details;
    this.errorCause = errorDetails.cause;

    // Maintains proper stack trace for where our error was thrown
    if (Error.captureStackTrace) {
      Error.captureStackTrace(this, AppError);
    }
  }

  /**
   * Convert error to JSON for API responses
   */
  toJSON() {
    return {
      name: this.name,
      code: this.code,
      message: this.message,
      statusCode: this.statusCode,
      details: this.details,
      // Don't expose stack trace in production
      ...(process.env.NODE_ENV === 'development' && { stack: this.stack })
    };
  }
}

/**
 * Database-related error
 */
export class DatabaseError extends AppError {
  constructor(message: string, details?: Record<string, any>, cause?: Error) {
    super({
      code: ErrorCode.DATABASE_QUERY_ERROR,
      message,
      statusCode: 500,
      details,
      cause
    });
    this.name = 'DatabaseError';
  }
}

/**
 * Authentication-related error
 */
export class AuthenticationError extends AppError {
  constructor(message: string = 'Authentication required', details?: Record<string, any>) {
    super({
      code: ErrorCode.AUTHENTICATION_REQUIRED,
      message,
      statusCode: 401,
      details
    });
    this.name = 'AuthenticationError';
  }
}

/**
 * Authorization-related error
 */
export class AuthorizationError extends AppError {
  constructor(message: string = 'Access denied', details?: Record<string, any>) {
    super({
      code: ErrorCode.AUTHORIZATION_FAILED,
      message,
      statusCode: 403,
      details
    });
    this.name = 'AuthorizationError';
  }
}

/**
 * Validation-related error
 */
export class ValidationError extends AppError {
  constructor(message: string, details?: Record<string, any>) {
    super({
      code: ErrorCode.VALIDATION_ERROR,
      message,
      statusCode: 400,
      details
    });
    this.name = 'ValidationError';
  }
}

/**
 * Resource not found error
 */
export class NotFoundError extends AppError {
  constructor(resource: string, id?: string | number) {
    const message = id ? `${resource} with id ${id} not found` : `${resource} not found`;
    super({
      code: ErrorCode.RESOURCE_NOT_FOUND,
      message,
      statusCode: 404,
      details: { resource, id }
    });
    this.name = 'NotFoundError';
  }
}

/**
 * External service error
 */
export class ExternalServiceError extends AppError {
  constructor(service: string, message: string, cause?: Error) {
    super({
      code: ErrorCode.EXTERNAL_API_ERROR,
      message: `${service} error: ${message}`,
      statusCode: 502,
      details: { service },
      cause
    });
    this.name = 'ExternalServiceError';
  }
}

/**
 * Error handler utility functions
 */
export const ErrorHandler = {
  /**
   * Handle Supabase errors and convert to appropriate AppError
   */
  handleSupabaseError(error: any): AppError {
    if (error?.code === 'PGRST116') {
      return new NotFoundError('Resource');
    }
    
    if (error?.code?.startsWith('42')) {
      return new DatabaseError('Database query error', { supabaseError: error });
    }
    
    return new DatabaseError(error?.message || 'Unknown database error', { supabaseError: error });
  },

  /**
   * Handle fetch errors and convert to appropriate AppError
   */
  handleFetchError(error: any, service: string = 'External API'): AppError {
    if (error?.name === 'TypeError' && error?.message?.includes('fetch')) {
      return new ExternalServiceError(service, 'Network connection failed', error);
    }
    
    return new ExternalServiceError(service, error?.message || 'Unknown error', error);
  },

  /**
   * Log error with appropriate level based on error type
   */
  logError(error: Error | AppError, context?: string): void {
    const contextStr = context ? `[${context}] ` : '';
    
    if (error instanceof AppError) {
      // Log different error types with different levels
      if (error.statusCode >= 500) {
        console.error(`${contextStr}${error.name}: ${error.message}`, {
          code: error.code,
          statusCode: error.statusCode,
          details: error.details,
          stack: error.stack
        });
      } else if (error.statusCode >= 400) {
        console.warn(`${contextStr}${error.name}: ${error.message}`, {
          code: error.code,
          statusCode: error.statusCode,
          details: error.details
        });
      }
    } else {
      console.error(`${contextStr}Unhandled error: ${error.message}`, error);
    }
  }
};
