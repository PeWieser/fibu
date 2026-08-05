import type { Config } from 'tailwindcss';

const config: Config = {
  content: ['./App.{js,jsx,ts,tsx}', './src/**/*.{js,jsx,ts,tsx}'],
  presets: [require('nativewind/preset')],
  theme: {
    extend: {
      colors: {
        canvas: {
          light: '#F8FAFC',
          dark: '#090D16'
        },
        surface: {
          light: '#FFFFFF',
          dark: '#131C2E',
          raisedLight: '#F1F5F9',
          raisedDark: '#1E293B'
        },
        accent: {
          DEFAULT: '#3B82F6',
          muted: '#1D4ED8'
        },
        border: {
          subtleLight: '#E2E8F0',
          subtleDark: '#1E293B',
          defaultLight: '#CBD5E1',
          defaultDark: '#334155'
        }
      }
    }
  },
  plugins: []
};

export default config;
