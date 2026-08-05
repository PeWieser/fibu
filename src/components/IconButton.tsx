import React from 'react';
import { Pressable, ActivityIndicator, ViewStyle, StyleProp } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withTiming,
  Easing,
} from 'react-native-reanimated';
import { useTheme } from '../theme/theme';

export type IconButtonVariant = 'primary' | 'secondary' | 'outline' | 'ghost';
export type IconButtonSize = 'sm' | 'md' | 'lg';

export interface IconButtonProps {
  icon: React.ReactNode;
  onPress: () => void;
  accessibilityLabel: string; // REQUIRED for accessibility compliance
  variant?: IconButtonVariant;
  size?: IconButtonSize;
  disabled?: boolean;
  loading?: boolean;
  accessibilityHint?: string;
  style?: StyleProp<ViewStyle>;
}

const AnimatedPressable = Animated.createAnimatedComponent(Pressable);

export const IconButton: React.FC<IconButtonProps> = ({
  icon,
  onPress,
  accessibilityLabel,
  variant = 'ghost',
  size = 'md',
  disabled = false,
  loading = false,
  accessibilityHint,
  style,
}) => {
  const { colors, borderRadius } = useTheme();
  const scale = useSharedValue(1);

  const handlePressIn = () => {
    scale.value = withTiming(0.92, {
      duration: 150,
      easing: Easing.out(Easing.ease),
    });
  };

  const handlePressOut = () => {
    scale.value = withTiming(1, {
      duration: 150,
      easing: Easing.out(Easing.ease),
    });
  };

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
  }));

  const getDimensions = (): { dim: number } => {
    switch (size) {
      case 'sm':
        return { dim: 44 };
      case 'lg':
        return { dim: 52 };
      case 'md':
      default:
        return { dim: 44 };
    }
  };

  const getVariantStyles = () => {
    if (disabled) {
      return {
        bg: colors.bg.surfaceRaised,
        border: colors.border.subtle,
        borderWidth: 1,
        indicatorColor: colors.text.muted,
      };
    }

    switch (variant) {
      case 'primary':
        return {
          bg: colors.accent.default,
          border: 'transparent',
          borderWidth: 0,
          indicatorColor: colors.text.inverse,
        };
      case 'secondary':
        return {
          bg: colors.accent.muted,
          border: 'transparent',
          borderWidth: 0,
          indicatorColor: colors.accent.default,
        };
      case 'outline':
        return {
          bg: 'transparent',
          border: colors.border.default,
          borderWidth: 1,
          indicatorColor: colors.text.primary,
        };
      case 'ghost':
      default:
        return {
          bg: 'transparent',
          border: 'transparent',
          borderWidth: 0,
          indicatorColor: colors.accent.default,
        };
    }
  };

  const { dim } = getDimensions();
  const variantStyle = getVariantStyles();

  return (
    <AnimatedPressable
      onPress={onPress}
      onPressIn={handlePressIn}
      onPressOut={handlePressOut}
      disabled={disabled || loading}
      accessibilityRole="button"
      accessibilityLabel={accessibilityLabel}
      accessibilityHint={accessibilityHint}
      accessibilityState={{ disabled: disabled || loading, busy: loading }}
      style={[
        animatedStyle,
        {
          width: dim,
          height: dim,
          minWidth: 44,
          minHeight: 44,
          borderRadius: borderRadius.lg,
          backgroundColor: variantStyle.bg,
          borderColor: variantStyle.border,
          borderWidth: variantStyle.borderWidth,
          alignItems: 'center',
          justifyContent: 'center',
          opacity: disabled ? 0.5 : 1,
        },
        style,
      ]}
    >
      {loading ? (
        <ActivityIndicator color={variantStyle.indicatorColor} size="small" />
      ) : (
        icon
      )}
    </AnimatedPressable>
  );
};
