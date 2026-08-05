import React, { useEffect } from 'react';
import { View, ViewStyle, StyleProp } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withTiming,
  Easing,
} from 'react-native-reanimated';
import { useTheme } from '../theme/theme';

export type ProgressBarColor = 'accent' | 'ok' | 'warn' | 'error';

export interface ProgressBarProps {
  progress: number; // 0.0 to 1.0
  height?: number;
  color?: ProgressBarColor;
  trackColor?: string;
  animated?: boolean;
  accessibilityLabel?: string;
  style?: StyleProp<ViewStyle>;
}

export const ProgressBar: React.FC<ProgressBarProps> = ({
  progress,
  height = 8,
  color = 'accent',
  trackColor,
  animated = true,
  accessibilityLabel,
  style,
}) => {
  const { colors, borderRadius } = useTheme();
  const clamped = Math.min(Math.max(progress, 0), 1);
  const widthShared = useSharedValue(clamped);

  useEffect(() => {
    if (animated) {
      widthShared.value = withTiming(clamped, {
        duration: 200,
        easing: Easing.out(Easing.ease),
      });
    } else {
      widthShared.value = clamped;
    }
  }, [clamped, animated, widthShared]);

  const animatedStyle = useAnimatedStyle(() => ({
    width: `${widthShared.value * 100}%`,
  }));

  const getBarColor = (): string => {
    switch (color) {
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

  const bgTrack = trackColor || colors.bg.surfaceRaised;

  return (
    <View
      accessibilityRole="progressbar"
      accessibilityLabel={
        accessibilityLabel || `Progress bar: ${Math.round(clamped * 100)}%`
      }
      accessibilityValue={{ min: 0, max: 100, now: Math.round(clamped * 100) }}
      style={[
        {
          height,
          width: '100%',
          backgroundColor: bgTrack,
          borderRadius: borderRadius.sm,
          overflow: 'hidden',
        },
        style,
      ]}
    >
      <Animated.View
        style={[
          {
            height: '100%',
            backgroundColor: getBarColor(),
            borderRadius: borderRadius.sm,
          },
          animatedStyle,
        ]}
      />
    </View>
  );
};
