/** @type {import('eslint').Linter.Config[]} */
const base = require('./index.js');

module.exports = [
  ...base,
  {
    files: ['**/*.{jsx,tsx}'],
    rules: {
      'no-console': ['warn', { allow: ['warn', 'error'] }],
    },
  },
];
