/**
 * Input validation utilities for forms and API endpoints
 * Provides comprehensive validation with detailed error messages
 */

import { ValidationError } from '~/utils/errors';

export interface ValidationRule {
  required?: boolean;
  minLength?: number;
  maxLength?: number;
  pattern?: RegExp;
  custom?: (value: any) => string | null; // Return error message or null if valid
}

export interface ValidationSchema {
  [key: string]: ValidationRule;
}

export interface ValidationResult {
  isValid: boolean;
  errors: Record<string, string>;
}

/**
 * Validates input against a schema
 */
export const validateInput = (data: Record<string, any>, schema: ValidationSchema): ValidationResult => {
  const errors: Record<string, string> = {};

  for (const [field, rules] of Object.entries(schema)) {
    const value = data[field];
    const fieldError = validateField(value, rules, field);
    
    if (fieldError) {
      errors[field] = fieldError;
    }
  }

  return {
    isValid: Object.keys(errors).length === 0,
    errors
  };
};

/**
 * Validates a single field against its rules
 */
const validateField = (value: any, rules: ValidationRule, fieldName: string): string | null => {
  // Required check
  if (rules.required && (value === null || value === undefined || value === '')) {
    return `${fieldName} is required`;
  }

  // If value is empty and not required, skip other validations
  if (!rules.required && (value === null || value === undefined || value === '')) {
    return null;
  }

  const stringValue = String(value);

  // Length checks
  if (rules.minLength && stringValue.length < rules.minLength) {
    return `${fieldName} must be at least ${rules.minLength} characters long`;
  }

  if (rules.maxLength && stringValue.length > rules.maxLength) {
    return `${fieldName} must not exceed ${rules.maxLength} characters`;
  }

  // Pattern check
  if (rules.pattern && !rules.pattern.test(stringValue)) {
    return `${fieldName} format is invalid`;
  }

  // Custom validation
  if (rules.custom) {
    return rules.custom(value);
  }

  return null;
};

/**
 * Common validation schemas
 */
export const ValidationSchemas = {
  plantskola: {
    name: {
      required: true,
      minLength: 2,
      maxLength: 100,
      pattern: /^[a-zA-ZåäöÅÄÖ\s\-\.]+$/
    },
    gatuadress: {
      required: true,
      minLength: 3,
      maxLength: 100
    },
    postnummer: {
      required: true,
      pattern: /^\d{3}\s?\d{2}$/ // Swedish postal code format
    },
    postort: {
      required: true,
      minLength: 2,
      maxLength: 50,
      pattern: /^[a-zA-ZåäöÅÄÖ\s\-]+$/
    },
    email: {
      required: true,
      pattern: /^[^\s@]+@[^\s@]+\.[^\s@]+$/,
      maxLength: 254
    },
    phone: {
      pattern: /^[\d\s\-\+\(\)]+$/,
      minLength: 8,
      maxLength: 20
    },
    url: {
      pattern: /^https?:\/\/.+\..+/,
      maxLength: 255
    },
    description: {
      maxLength: 1000
    }
  },

  plantSearch: {
    query: {
      maxLength: 100,
      custom: (value: string) => {
        if (typeof value !== 'string') return 'Search query must be a string';
        // Basic XSS prevention
        if (/<script|javascript:|data:/i.test(value)) {
          return 'Invalid characters in search query';
        }
        return null;
      }
    },
    sortBy: {
      custom: (value: string) => {
        const validSorts = ['relevance', 'popularity', 'name_asc', 'name_desc'];
        if (!validSorts.includes(value)) {
          return 'Invalid sort option';
        }
        return null;
      }
    },
    plantType: {
      pattern: /^[a-zA-Z0-9_]+$/,
      maxLength: 50
    }
  },

  fileUpload: {
    file: {
      required: true,
      custom: (file: File) => {
        if (!file || !(file instanceof File)) {
          return 'Valid file is required';
        }
        
        const maxSize = 5 * 1024 * 1024; // 5MB
        if (file.size > maxSize) {
          return 'File size must not exceed 5MB';
        }
        
        const allowedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];
        if (!allowedTypes.includes(file.type)) {
          return 'File must be JPEG, PNG, or WebP format';
        }
        
        return null;
      }
    }
  }
};

/**
 * Sanitizes string input to prevent XSS attacks
 */
export const sanitizeString = (input: string): string => {
  if (typeof input !== 'string') return '';
  
  return input
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#x27;')
    .replace(/\//g, '&#x2F;')
    .trim();
};

/**
 * Validates and sanitizes search input
 */
export const validateSearchInput = (query: string, sortBy?: string): { query: string; sortBy?: string } => {
  const validation = validateInput({ query, sortBy }, ValidationSchemas.plantSearch);
  
  if (!validation.isValid) {
    throw new ValidationError('Invalid search input', validation.errors);
  }
  
  return {
    query: sanitizeString(query),
    sortBy
  };
};

/**
 * Validates plantskola form data
 */
export const validatePlantskolaData = (data: Record<string, any>): ValidationResult => {
  return validateInput(data, ValidationSchemas.plantskola);
};

/**
 * Validates file upload
 */
export const validateFileUpload = (file: File): ValidationResult => {
  return validateInput({ file }, ValidationSchemas.fileUpload);
};
