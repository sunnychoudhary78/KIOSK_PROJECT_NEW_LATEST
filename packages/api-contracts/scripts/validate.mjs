import { readFileSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = dirname(fileURLToPath(import.meta.url));
const specPath = join(root, '..', 'openapi', 'openapi.yaml');

if (!existsSync(specPath)) {
  console.error('OpenAPI spec missing:', specPath);
  process.exit(1);
}

const content = readFileSync(specPath, 'utf8');
const required = ['openapi:', 'info:', 'paths:', '/health:', '/otp-challenges:', '/quick-print/sessions:', '/digilocker/sessions:'];

for (const token of required) {
  if (!content.includes(token)) {
    console.error(`OpenAPI contract validation failed: missing "${token}"`);
    process.exit(1);
  }
}

console.info('api-contracts: OpenAPI stub validation passed');
