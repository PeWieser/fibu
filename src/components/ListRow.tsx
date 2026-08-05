import React from 'react';
import { View, Pressable, ViewStyle, StyleProp } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withTiming,
  Easing,
} from 'react-native-reanimated';
import { useTheme } from '../theme/theme';
import { Text } from './Text';

export interface ListRowProps {
  title: string;
  subtitle?: string;
  leftIcon?: React.ReactNode;
  rightIcon?: React.ReactNode;
  value?: string;
  onPress?: () => void;
  disabled?: boolean;
  showBorder?: boolean;
  accessibilityLabel?: string;
  accessibilityHint?: string;
  style?: StyleProp<ViewStyle>;
}

const AnimatedPressable = Animated.createAnimatedComponent(Pressable);

export const ListRow: React.FC<ListRowProps> = ({
  title,
  subtitle,
  leftIcon,
  rightIcon,
  value,
  onPress,
  disabled = false,
  showBorder = true,
  accessibilityLabel,
  accessibilityHint,
  style,
}) => {
  const { colors, spacing } = useTheme();
  const opacity = useSharedValue(1);

  const handlePressIn = () => {
    if (onPress) {
      opacity.value = withTiming(0.7, {
        duration: 150,
        easing: Easing.out(Easing.ease),
      });
    }
  };

  const handlePressOut = () => {
    if (onPress) {
      opacity.value = withTiming(1, {
        duration: 150,
        easing: Easing.out(Easing.ease),
      });
    }
  };

  const animatedStyle = useAnimatedStyle(() => ({
    opacity: opacity.value,
  }));

  const content = (
    <View
      style={[
        {
          minHeight: 56, // >= 44pt touch target requirement
          paddingVertical: spacing.md,
          paddingHorizontal: spacing.lg,
          flexDirection: 'row',
          alignItems: 'center',
          backgroundColor: colors.bg.surface,
          borderBottomWidth: showBorder ? 1 : 0,
          borderBottomColor: colors.border.subtle,
          gap: spacing.md,
        },
        style,
      ]}
    >
      {leftIcon ? <View style={{ justifyContent: 'center' }}>{leftIcon}</View> : null}

      <View style={{ flex: 1, justifyContent: 'center' }}>
        <Text variant="base" weight="semibold" color={disabled ? 'muted' : 'primary'}>
          {title}
        </Text>
        {subtitle ? (
          <Text variant="sm" color="muted" style={{ marginTop: spacing.xs / 2 }}>
            {subtitle}
          </Text>
        ) : null}
      </View>

      {value ? (
        <Text variant="sm" color="secondary" weight="medium">
          {value}
        </Text>
      ) : null}

      {rightIcon ? <View style={{ justifyContent: 'center' }}>{rightIcon}</View> : null}
    </View>
  );

  if (onPress) {
    return (
      <AnimatedPressable
        onPress={onPress}
        onPressIn={handlePressIn}
        onPressOut={handlePressOut}
        disabled={disabled}
        accessibilityRole="button"
        accessibilityLabel={accessibilityLabel || title}
        accessibilityHint={accessibilityHint}
        accessibilityState={{ disabled }}
        style={animatedStyle}
      >
        {content}
      </AnimatedPressable>
    );
  }

  return (
    <View
      accessibilityRole="text"
      accessibilityLabel={accessibilityLabel || title}
    >
      {content}
    </View>
  );
};
