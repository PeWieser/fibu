import React from 'react';
import { Text as RNText, TextProps as RNTextProps, TextStyle, StyleProp } from 'react-native';
import { useTheme, TypographyVariant } from '../theme/theme';

export type TextColorKey =
  | 'primary'
  | 'secondary'
  | 'muted'
  | 'inverse'
  | 'accent'
  | 'ok'
  | 'warn'
  | 'error';

export type FontWeightKey = 'normal' | 'medium' | 'semibold' | 'bold';

export interface TextProps extends RNTextProps {
  variant?: TypographyVariant;
  color?: TextColorKey;
  weight?: FontWeightKey;
  align?: 'left' | 'center' | 'right' | 'justify';
  children?: React.ReactNode;
  style?: StyleProp<TextStyle>;
}

const weightMap: Record<FontWeightKey, TextStyle['fontWeight']> = {
  normal: '400',
  medium: '500',
  semibold: '600',
  bold: '700',
};

export const Text: React.FC<TextProps> = ({
  variant = 'base',
  color = 'primary',
  weight = 'normal',
  align = 'left',
  children,
  style,
  accessibilityRole = 'text',
  ...props
}) => {
  const { colors, typography } = useTheme();

  const getColor = (cKey: TextColorKey): string => {
    switch (cKey) {
      case 'primary':
        return colors.text.primary;
      case 'secondary':
        return colors.text.secondary;
      case 'muted':
        return colors.text.muted;
      case 'inverse':
        return colors.text.inverse;
      case 'accent':
        return colors.accent.default;
      case 'ok':
        return colors.status.ok;
      case 'warn':
        return colors.status.warn;
      case 'error':
        return colors.status.error;
    }
  };

  const typoStyle = typography[variant];
  const colorValue = getColor(color);

  return (
    <RNText
      accessibilityRole={accessibilityRole}
      style={[
        {
          fontSize: typoStyle.fontSize,
          lineHeight: typoStyle.lineHeight,
          color: colorValue,
          fontWeight: weightMap[weight],
          textAlign: align,
        },
        style,
      ]}
      {...props}
    >
      {children}
    </RNText>
  );
};
