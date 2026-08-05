import React from 'react';
import { View, ViewStyle, StyleProp } from 'react-native';
import { useTheme } from '../theme/theme';
import { Text } from './Text';
import { Button } from './Button';

export interface EmptyStateProps {
  title: string;
  description?: string;
  icon?: React.ReactNode;
  actionLabel?: string;
  onAction?: () => void;
  accessibilityLabel?: string;
  style?: StyleProp<ViewStyle>;
}

export const EmptyState: React.FC<EmptyStateProps> = ({
  title,
  description,
  icon,
  actionLabel,
  onAction,
  accessibilityLabel,
  style,
}) => {
  const { colors, spacing, borderRadius } = useTheme();

  return (
    <View
      accessibilityRole="summary"
      accessibilityLabel={accessibilityLabel || `${title}. ${description || ''}`}
      style={[
        {
          alignItems: 'center',
          justifyContent: 'center',
          padding: spacing.xl,
          backgroundColor: colors.bg.surface,
          borderRadius: borderRadius.lg,
          borderWidth: 1,
          borderColor: colors.border.subtle,
        },
        style,
      ]}
    >
      {icon ? (
        <View
          style={{
            marginBottom: spacing.md,
            padding: spacing.md,
            borderRadius: borderRadius.lg,
            backgroundColor: colors.bg.surfaceRaised,
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          {icon}
        </View>
      ) : null}

      <Text variant="lg" weight="bold" align="center" color="primary">
        {title}
      </Text>

      {description ? (
        <Text
          variant="sm"
          color="muted"
          align="center"
          style={{ marginTop: spacing.xs, maxWidth: 300 }}
        >
          {description}
        </Text>
      ) : null}

      {actionLabel && onAction ? (
        <View style={{ marginTop: spacing.lg }}>
          <Button label={actionLabel} onPress={onAction} variant="primary" />
        </View>
      ) : null}
    </View>
  );
};
