/**
 * Semantic tokens, type scale, and spacing grid for EchoVault.
 * Full implementation in Phase 1.
 */
export const theme = {
  colors: {
    accent: '#3B82F6',
    canvas: {
      light: '#F8FAFC',
      dark: '#090D16'
    },
    surface: {
      light: '#FFFFFF',
      dark: '#131C2E'
    },
    text: {
      primaryLight: '#0F172A',
      primaryDark: '#F8FAFC',
      mutedLight: '#64748B',
      mutedDark: '#94A3B8'
    }
  },
  spacing: {
    xs: 4,
    sm: 8,
    md: 12,
    lg: 16,
    xl: 24,
    '2xl': 32
  },
  borderRadius: {
    sm: 6,
    lg: 12
  }
} as const;

export type Theme = typeof theme;
