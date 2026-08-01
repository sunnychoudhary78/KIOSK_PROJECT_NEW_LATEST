import { AppError } from './errors.js';

export function requireParam(value: string | undefined, name: string): string {
  if (!value) {
    throw new AppError('validation_error', `Missing route parameter: ${name}`, 400);
  }
  return value;
}
