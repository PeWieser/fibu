import React, { createContext, useContext, useState, useMemo } from 'react';
import { useColorScheme as useRNColorScheme } from 'react-native';

export type ColorScheme = 'light' | 'dark';

export interface ThemeColors {
  bg: {
    canvas: string;
    surface: string;
    surfaceRaised: string;
  };
  text: {
    primary: string;
    secondary: string;
    muted: string;
    inverse: string;
  };
  border: {
    subtle: string;
    default: string;
  };
  accent: {
    default: string;
    muted: string;
  };
  status: {
    ok: string;
    warn: string;
    error: string;
  };
}

export const lightColors: ThemeColors = {
  bg: {
    canvas: '#F8FAFC',
    surface: '#FFFFFF',
    surfaceRaised: '#F1F5F9',
  },
  text: {
    primary: '#0F172A',
    secondary: '#334155',
    muted: '#64748B',
    inverse: '#FFFFFF',
  },
  border: {
    subtle: '#E2E8F0',
    default: '#CBD5E1',
  },
  accent: {
    default: '#3B82F6',
    muted: '#DBEAFE',
  },
  status: {
    ok: '#16A34A',
    warn: '#D97706',
    error: '#DC2626',
  },
};

export const darkColors: ThemeColors = {
  bg: {
    canvas: '#090D16',
    surface: '#131C2E',
    surfaceRaised: '#1E293B',
  },
  text: {
    primary: '#F8FAFC',
    secondary: '#CBD5E1',
    muted: '#94A3B8',
    inverse: '#0F172A',
  },
  border: {
    subtle: '#1E293B',
    default: '#334155',
  },
  accent: {
    default: '#3B82F6',
    muted: '#1E3A8A',
  },
  status: {
    ok: '#22C55E',
    warn: '#F59E0B',
    error: '#EF4444',
  },
};

export const spacing = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 24,
  '2xl': 32,
} as const;

export type SpacingKey = keyof typeof spacing;

export const borderRadius = {
  sm: 6,
  lg: 12,
} as const;

export type BorderRadiusKey = keyof typeof borderRadius;

export const typography = {
  xs: {
    fontSize: 12,
    lineHeight: 16,
  },
  sm: {
    fontSize: 14,
    lineHeight: 20,
  },
  base: {
    fontSize: 16,
    lineHeight: 24,
  },
  lg: {
    fontSize: 20,
    lineHeight: 28,
  },
  xl: {
    fontSize: 28,
    lineHeight: 36,
  },
} as const;

export type TypographyVariant = keyof typeof typography;

export const theme = {
  colors: lightColors,
  spacing,
  borderRadius,
  typography,
  accentColor: '#3B82F6',
} as const;

export type Theme = typeof theme;

export interface ThemeContextValue {
  colorScheme: ColorScheme;
  colors: ThemeColors;
  spacing: typeof spacing;
  borderRadius: typeof borderRadius;
  typography: typeof typography;
  setColorScheme: (scheme: ColorScheme) => void;
  toggleColorScheme: () => void;
}

const ThemeContext = createContext<ThemeContextValue>({
  colorScheme: 'light',
  colors: lightColors,
  spacing,
  borderRadius,
  typography,
  setColorScheme: () => {},
  toggleColorScheme: () => {},
});

export interface ThemeProviderProps {
  children: React.ReactNode;
  initialColorScheme?: ColorScheme;
}

export const ThemeProvider: React.FC<ThemeProviderProps> = ({ children, initialColorScheme }) => {
  const systemScheme = useRNColorScheme();
  const [colorScheme, setColorScheme] = useState<ColorScheme>(
    initialColorScheme || (systemScheme === 'dark' ? 'dark' : 'light')
  );

  const toggleColorScheme = () => {
    setColorScheme((prev) => (prev === 'light' ? 'dark' : 'light'));
  };

  const colors = colorScheme === 'dark' ? darkColors : lightColors;

  const value = useMemo(
    () => ({
      colorScheme,
      colors,
      spacing,
      borderRadius,
      typography,
      setColorScheme,
      toggleColorScheme,
    }),
    [colorScheme, colors]
  );

  return React.createElement(ThemeContext.Provider, { value }, children);
};

export const useTheme = (): ThemeContextValue => {
  return useContext(ThemeContext);
};
