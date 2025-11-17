import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    include: [
      'src/**/__tests__/**/*.test.ts',
      'src/**/__tests__/**/*.spec.ts',
      'src/tests/**/*.test.ts',
      'src/tests/**/*.spec.ts',
    ],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
      exclude: [
        'node_modules/',
        'dist/',
        '**/*.test.ts',
        '**/*.spec.ts',
        '**/__tests__/**',
        'src/tests/**',
        'coverage/',
      ],
      thresholds: {
        lines: 80, // Phase 7 target: >80% coverage for core services
        functions: 80,
        branches: 80,
        statements: 80,
      },
    },
  },
});

