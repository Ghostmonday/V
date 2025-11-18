import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    env: {
      NEXT_PUBLIC_SUPABASE_URL: 'https://test.supabase.co',
      NEXT_PUBLIC_SUPABASE_ANON_KEY: 'test-anon-key',
      SUPABASE_SERVICE_ROLE_KEY: 'test-service-role-key',
      JWT_SECRET: 'test-jwt-secret-key-for-testing-only',
      ENCRYPTION_MASTER_KEY: 'test-encryption-key-32-bytes-long!!',
    },
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
