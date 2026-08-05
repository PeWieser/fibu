import React, { useEffect } from 'react';
import { View, ViewStyle, StyleProp } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withTiming,
  Easing,
} from 'react-native-reanimated';
import { useTheme } from '../theme/theme';
import { Text } from './Text';

export interface ProgressRingProps {
  progress: number; // 0.0 to 1.0
  size?: number;
  strokeWidth?: number;
  color?: string;
  trackColor?: string;
  showValue?: boolean;
  accessibilityLabel?: string;
  style?: StyleProp<ViewStyle>;
}

export const ProgressRing: React.FC<ProgressRingProps> = ({
  progress,
  size = 48,
  strokeWidth = 4,
  color,
  trackColor,
  showValue = false,
  accessibilityLabel,
  style,
}) => {
  const { colors } = useTheme();
  const clampedProgress = Math.min(Math.max(progress, 0), 1);
  const activeColor = color || colors.accent.default;
  const inactiveColor = trackColor || colors.border.subtle;

  const animatedProgress = useSharedValue(clampedProgress);

  useEffect(() => {
    animatedProgress.value = withTiming(clampedProgress, {
      duration: 200,
      easing: Easing.out(Easing.ease),
    });
  }, [clampedProgress, animatedProgress]);

  const rightHalfStyle = useAnimatedStyle(() => {
    const deg = Math.min(animatedProgress.value * 360, 180);
    return {
      transform: [{ rotate: `${deg}deg` }],
    };
  });

  const leftHalfStyle = useAnimatedStyle(() => {
    const deg = Math.max((animatedProgress.value - 0.5) * 360, 0);
    return {
      transform: [{ rotate: `${deg}deg` }],
    };
  });

  const halfSize = size / 2;

  return (
    <View
      accessibilityRole="progressbar"
      accessibilityLabel={
        accessibilityLabel || `Progress ring: ${Math.round(clampedProgress * 100)}%`
      }
      accessibilityValue={{ min: 0, max: 100, now: Math.round(clampedProgress * 100) }}
      style={[
        {
          width: size,
          height: size,
          alignItems: 'center',
          justifyContent: 'center',
        },
        style,
      ]}
    >
      {/* Background Track Circle */}
      <View
        style={{
          width: size,
          height: size,
          borderRadius: halfSize,
          borderWidth: strokeWidth,
          borderColor: inactiveColor,
          position: 'absolute',
        }}
      />

      {/* Right Half Container (0 - 180 deg) */}
      <View
        style={{
          width: halfSize,
          height: size,
          position: 'absolute',
          right: 0,
          overflow: 'hidden',
        }}
      >
        <Animated.View
          style={[
            {
              width: size,
              height: size,
              borderRadius: halfSize,
              borderWidth: strokeWidth,
              borderColor: activeColor,
              position: 'absolute',
              right: 0,
            },
            rightHalfStyle,
          ]}
        />
      </View>

      {/* Left Half Container (180 - 360 deg) */}
      <View
        style={{
          width: halfSize,
          height: size,
          position: 'absolute',
          left: 0,
          overflow: 'hidden',
        }}
      >
        <Animated.View
          style={[
            {
              width: size,
              height: size,
              borderRadius: halfSize,
              borderWidth: strokeWidth,
              borderColor: activeColor,
              position: 'absolute',
              left: 0,
            },
            leftHalfStyle,
          ]}
        />
      </View>

      {showValue ? (
        <Text variant="xs" weight="semibold" color="primary">
          {`${Math.round(clampedProgress * 100)}%`}
        </Text>
      ) : null}
    </View>
  );
};
