module.exports = {
  preset: 'jest-expo',
  testMatch: ['**/__tests__/**/*.test.ts', '**/__tests__/**/*.test.tsx'],
  moduleNameMapper: {
    '^test-renderer$': 'react-test-renderer'
  },
  setupFiles: ['<rootDir>/__tests__/helpers/jest.setup.js']
};
