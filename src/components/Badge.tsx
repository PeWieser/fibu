import React from 'react';
import { View, ViewStyle, StyleProp } from 'react-native';
import { useTheme } from '../theme/theme';
import { Text } from './Text';

export type BadgeVariant = 'default' | 'accent' | 'ok' | 'warn' | 'error' | 'outline';
export type BadgeSize = 'sm' | 'md';

export interface BadgeProps {
  label: string;
  variant?: BadgeVariant;
  size?: BadgeSize;
  accessibilityLabel?: string;
  style?: StyleProp<ViewStyle>;
}

export const Badge: React.FC<BadgeProps> = ({
  label,
  variant = 'default',
  size = 'md',
  accessibilityLabel,
  style,
}) => {
  const { colors, spacing, borderRadius } = useTheme();

  const getVariantStyles = () => {
    switch (variant) {
      case 'accent':
        return {
          bg: colors.accent.muted,
          border: 'transparent',
          textColor: 'accent' as const,
        };
      case 'ok':
        return {
          bg: colors.bg.surfaceRaised,
          border: colors.status.ok,
          textColor: 'ok' as const,
        };
      case 'warn':
        return {
          bg: colors.bg.surfaceRaised,
          border: colors.status.warn,
          textColor: 'warn' as const,
        };
      case 'error':
        return {
          bg: colors.bg.surfaceRaised,
          border: colors.status.error,
          textColor: 'error' as const,
        };
      case 'outline':
        return {
          bg: 'transparent',
          border: colors.border.default,
          textColor: 'primary' as const,
        };
      case 'default':
      default:
        return {
          bg: colors.bg.surfaceRaised,
          border: 'transparent',
          textColor: 'secondary' as const,
        };
    }
  };

  const variantStyle = getVariantStyles();
  const isSm = size === 'sm';

  return (
    <View
      accessibilityRole="text"
      accessibilityLabel={accessibilityLabel || `Badge: ${label}`}
      style={[
        {
          paddingHorizontal: isSm ? spacing.xs : spacing.sm,
          paddingVertical: isSm ? 2 : spacing.xs,
          borderRadius: borderRadius.sm,
          backgroundColor: variantStyle.bg,
          borderColor: variantStyle.border,
          borderWidth: variantStyle.border !== 'transparent' ? 1 : 0,
          alignSelf: 'flex-start',
          alignItems: 'center',
          justifyContent: 'center',
        },
        style,
      ]}
    >
      <Text
        variant={isSm ? 'xs' : 'sm'}
        weight="medium"
        color={variantStyle.textColor}
      >
        {label}
      </Text>
    </View>
  );
};
