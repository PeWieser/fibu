import React, { useEffect } from 'react';
import { Pressable, ViewStyle, StyleProp } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withTiming,
  Easing,
  interpolateColor,
} from 'react-native-reanimated';
import { useTheme } from '../theme/theme';
import { Text } from './Text';

export interface ToggleProps {
  value: boolean;
  onValueChange: (value: boolean) => void;
  disabled?: boolean;
  label?: string;
  accessibilityLabel?: string;
  accessibilityHint?: string;
  style?: StyleProp<ViewStyle>;
}

const AnimatedPressable = Animated.createAnimatedComponent(Pressable);

export const Toggle: React.FC<ToggleProps> = ({
  value,
  onValueChange,
  disabled = false,
  label,
  accessibilityLabel,
  accessibilityHint,
  style,
}) => {
  const { colors, spacing, borderRadius } = useTheme();
  const progress = useSharedValue(value ? 1 : 0);

  useEffect(() => {
    progress.value = withTiming(value ? 1 : 0, {
      duration: 200,
      easing: Easing.out(Easing.ease),
    });
  }, [value, progress]);

  const activeBg = colors.accent.default;
  const inactiveBg = colors.border.default;

  const trackAnimatedStyle = useAnimatedStyle(() => {
    const backgroundColor = interpolateColor(
      progress.value,
      [0, 1],
      [inactiveBg, activeBg]
    );
    return {
      backgroundColor,
    };
  });

  const thumbAnimatedStyle = useAnimatedStyle(() => {
    return {
      transform: [{ translateX: progress.value * 20 }],
    };
  });

  const handlePress = () => {
    if (!disabled) {
      onValueChange(!value);
    }
  };

  return (
    <AnimatedPressable
      onPress={handlePress}
      disabled={disabled}
      accessibilityRole="switch"
      accessibilityLabel={accessibilityLabel || label || 'Toggle switch'}
      accessibilityHint={accessibilityHint}
      accessibilityState={{ checked: value, disabled }}
      style={[
        {
          flexDirection: 'row',
          alignItems: 'center',
          minHeight: 44, // Ensures >= 44pt touch target
          minWidth: 44,
          opacity: disabled ? 0.5 : 1,
          gap: spacing.sm,
        },
        style,
      ]}
    >
      {label ? (
        <Text variant="base" weight="medium" color="primary" style={{ flex: 1 }}>
          {label}
        </Text>
      ) : null}

      <Animated.View
        style={[
          {
            width: 48,
            height: 28,
            borderRadius: borderRadius.lg,
            padding: 2,
            justifyContent: 'center',
          },
          trackAnimatedStyle,
        ]}
      >
        <Animated.View
          style={[
            {
              width: 24,
              height: 24,
              borderRadius: borderRadius.lg,
              backgroundColor: colors.bg.surface,
            },
            thumbAnimatedStyle,
          ]}
        />
      </Animated.View>
    </AnimatedPressable>
  );
};
