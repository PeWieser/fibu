import React from 'react';
import { View, ViewProps, ViewStyle, StyleProp } from 'react-native';
import { useTheme, SpacingKey, BorderRadiusKey } from '../theme/theme';

export type SurfaceElevation = 'canvas' | 'surface' | 'surfaceRaised';
export type SurfaceBorder = boolean | 'subtle' | 'default';

export interface SurfaceProps extends ViewProps {
  elevation?: SurfaceElevation;
  borderRadius?: BorderRadiusKey | 'none';
  padding?: SpacingKey;
  border?: SurfaceBorder;
  children?: React.ReactNode;
  style?: StyleProp<ViewStyle>;
}

export const Surface: React.FC<SurfaceProps> = ({
  elevation = 'surface',
  borderRadius: radiusKey = 'lg',
  padding: paddingKey,
  border = false,
  children,
  style,
  ...props
}) => {
  const { colors, spacing, borderRadius } = useTheme();

  const getBgColor = (): string => {
    switch (elevation) {
      case 'canvas':
        return colors.bg.canvas;
      case 'surface':
        return colors.bg.surface;
      case 'surfaceRaised':
        return colors.bg.surfaceRaised;
    }
  };

  const getBorderColor = (): string | undefined => {
    if (!border) return undefined;
    if (border === 'subtle' || border === true) return colors.border.subtle;
    if (border === 'default') return colors.border.default;
    return undefined;
  };

  const radiusValue = radiusKey === 'none' ? 0 : borderRadius[radiusKey];
  const paddingValue = paddingKey ? spacing[paddingKey] : undefined;
  const borderColor = getBorderColor();

  return (
    <View
      style={[
        {
          backgroundColor: getBgColor(),
          borderRadius: radiusValue,
          padding: paddingValue,
          borderWidth: border ? 1 : 0,
          borderColor,
        },
        style,
      ]}
      {...props}
    >
      {children}
    </View>
  );
};
