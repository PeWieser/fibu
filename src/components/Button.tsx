import React from 'react';
import {
  Pressable,
  ActivityIndicator,
  ViewStyle,
  StyleProp,
  View,
} from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withTiming,
  Easing,
} from 'react-native-reanimated';
import { useTheme } from '../theme/theme';
import { Text } from './Text';

export type ButtonVariant = 'primary' | 'secondary' | 'outline' | 'ghost' | 'danger';
export type ButtonSize = 'sm' | 'md' | 'lg';

export interface ButtonProps {
  label: string;
  onPress: () => void;
  variant?: ButtonVariant;
  size?: ButtonSize;
  disabled?: boolean;
  loading?: boolean;
  icon?: React.ReactNode;
  iconPosition?: 'left' | 'right';
  fullWidth?: boolean;
  accessibilityLabel?: string;
  accessibilityHint?: string;
  style?: StyleProp<ViewStyle>;
}

const AnimatedPressable = Animated.createAnimatedComponent(Pressable);

export const Button: React.FC<ButtonProps> = ({
  label,
  onPress,
  variant = 'primary',
  size = 'md',
  disabled = false,
  loading = false,
  icon,
  iconPosition = 'left',
  fullWidth = false,
  accessibilityLabel,
  accessibilityHint,
  style,
}) => {
  const { colors, spacing, borderRadius } = useTheme();
  const scale = useSharedValue(1);
  const opacity = useSharedValue(1);

  const handlePressIn = () => {
    scale.value = withTiming(0.97, {
      duration: 150,
      easing: Easing.out(Easing.ease),
    });
    opacity.value = withTiming(0.9, { duration: 150 });
  };

  const handlePressOut = () => {
    scale.value = withTiming(1, {
      duration: 150,
      easing: Easing.out(Easing.ease),
    });
    opacity.value = withTiming(1, { duration: 150 });
  };

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
    opacity: opacity.value,
  }));

  const getSizeStyles = () => {
    switch (size) {
      case 'sm':
        return {
          minHeight: 44,
          paddingHorizontal: spacing.md,
          paddingVertical: spacing.xs,
          textSize: 'sm' as const,
        };
      case 'lg':
        return {
          minHeight: 52,
          paddingHorizontal: spacing.xl,
          paddingVertical: spacing.md,
          textSize: 'lg' as const,
        };
      case 'md':
      default:
        return {
          minHeight: 44,
          paddingHorizontal: spacing.lg,
          paddingVertical: spacing.sm,
          textSize: 'base' as const,
        };
    }
  };

  const getVariantStyles = () => {
    if (disabled) {
      return {
        bg: colors.bg.surfaceRaised,
        border: colors.border.subtle,
        borderWidth: 1,
        textColor: colors.text.muted,
      };
    }

    switch (variant) {
      case 'primary':
        return {
          bg: colors.accent.default,
          border: 'transparent',
          borderWidth: 0,
          textColor: colors.text.inverse,
        };
      case 'secondary':
        return {
          bg: colors.accent.muted,
          border: 'transparent',
          borderWidth: 0,
          textColor: colors.accent.default,
        };
      case 'outline':
        return {
          bg: 'transparent',
          border: colors.border.default,
          borderWidth: 1,
          textColor: colors.text.primary,
        };
      case 'ghost':
        return {
          bg: 'transparent',
          border: 'transparent',
          borderWidth: 0,
          textColor: colors.accent.default,
        };
      case 'danger':
        return {
          bg: colors.status.error,
          border: 'transparent',
          borderWidth: 0,
          textColor: colors.text.inverse,
        };
    }
  };

  const sizeStyle = getSizeStyles();
  const variantStyle = getVariantStyles();

  return (
    <AnimatedPressable
      onPress={onPress}
      onPressIn={handlePressIn}
      onPressOut={handlePressOut}
      disabled={disabled || loading}
      accessibilityRole="button"
      accessibilityLabel={accessibilityLabel || label}
      accessibilityHint={accessibilityHint}
      accessibilityState={{ disabled: disabled || loading, busy: loading }}
      style={[
        animatedStyle,
        {
          minHeight: sizeStyle.minHeight,
          minWidth: 44,
          paddingHorizontal: sizeStyle.paddingHorizontal,
          paddingVertical: sizeStyle.paddingVertical,
          borderRadius: borderRadius.lg,
          backgroundColor: variantStyle.bg,
          borderColor: variantStyle.border,
          borderWidth: variantStyle.borderWidth,
          flexDirection: 'row',
          alignItems: 'center',
          justifyContent: 'center',
          alignSelf: fullWidth ? 'stretch' : 'flex-start',
          opacity: disabled ? 0.6 : 1,
        },
        style,
      ]}
    >
      {loading ? (
        <ActivityIndicator color={variantStyle.textColor} size="small" />
      ) : (
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.xs }}>
          {icon && iconPosition === 'left' ? icon : null}
          <Text
            variant={sizeStyle.textSize}
            weight="semibold"
            style={{ color: variantStyle.textColor }}
          >
            {label}
          </Text>
          {icon && iconPosition === 'right' ? icon : null}
        </View>
      )}
    </AnimatedPressable>
  );
};
