import React, { useEffect } from 'react';
import {
  Modal,
  View,
  Pressable,
  ViewStyle,
  StyleProp,
} from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withTiming,
  Easing,
  runOnJS,
} from 'react-native-reanimated';
import { useTheme } from '../theme/theme';
import { Text } from './Text';

export interface SheetProps {
  isOpen: boolean;
  onClose: () => void;
  title?: string;
  children: React.ReactNode;
  accessibilityLabel?: string;
  style?: StyleProp<ViewStyle>;
}

const AnimatedPressable = Animated.createAnimatedComponent(Pressable);

export const Sheet: React.FC<SheetProps> = ({
  isOpen,
  onClose,
  title,
  children,
  accessibilityLabel,
  style,
}) => {
  const { colors, spacing, borderRadius } = useTheme();
  const backdropOpacity = useSharedValue(0);
  const translateY = useSharedValue(300);
  const [modalVisible, setModalVisible] = React.useState(isOpen);

  useEffect(() => {
    if (isOpen) {
      setModalVisible(true);
      backdropOpacity.value = withTiming(1, {
        duration: 200,
        easing: Easing.out(Easing.ease),
      });
      translateY.value = withTiming(0, {
        duration: 250,
        easing: Easing.out(Easing.ease),
      });
    } else if (modalVisible) {
      backdropOpacity.value = withTiming(0, { duration: 200 });
      translateY.value = withTiming(
        300,
        { duration: 200, easing: Easing.in(Easing.ease) },
        (finished) => {
          if (finished) {
            runOnJS(setModalVisible)(false);
          }
        }
      );
    }
  }, [isOpen, modalVisible, backdropOpacity, translateY]);

  const backdropStyle = useAnimatedStyle(() => ({
    opacity: backdropOpacity.value,
  }));

  const sheetStyle = useAnimatedStyle(() => ({
    transform: [{ translateY: translateY.value }],
  }));

  if (!modalVisible) return null;

  return (
    <Modal
      transparent
      visible={modalVisible}
      onRequestClose={onClose}
      animationType="none"
    >
      <View
        accessibilityViewIsModal
        accessibilityLabel={accessibilityLabel || title || 'Bottom sheet'}
        style={{ flex: 1, justifyContent: 'flex-end' }}
      >
        {/* Backdrop overlay */}
        <AnimatedPressable
          onPress={onClose}
          accessibilityRole="button"
          accessibilityLabel="Close modal backdrop"
          style={[
            {
              ...ViewStyleSheetAbsoluteFill(),
              backgroundColor: 'rgba(0, 0, 0, 0.5)',
            },
            backdropStyle,
          ]}
        />

        {/* Sheet Surface */}
        <Animated.View
          style={[
            {
              backgroundColor: colors.bg.surface,
              borderTopLeftRadius: borderRadius.lg,
              borderTopRightRadius: borderRadius.lg,
              paddingTop: spacing.sm,
              paddingBottom: spacing['2xl'],
              paddingHorizontal: spacing.lg,
              maxHeight: '85%',
              borderWidth: 1,
              borderColor: colors.border.subtle,
            },
            sheetStyle,
            style,
          ]}
        >
          {/* Drag handle indicator */}
          <View style={{ alignItems: 'center', marginVertical: spacing.xs }}>
            <View
              style={{
                width: 36,
                height: 4,
                borderRadius: borderRadius.sm,
                backgroundColor: colors.border.default,
              }}
            />
          </View>

          {/* Header */}
          {title ? (
            <View
              style={{
                flexDirection: 'row',
                alignItems: 'center',
                justifyContent: 'space-between',
                marginBottom: spacing.md,
                paddingTop: spacing.xs,
              }}
            >
              <Text variant="lg" weight="semibold" color="primary">
                {title}
              </Text>
              <Pressable
                onPress={onClose}
                accessibilityRole="button"
                accessibilityLabel="Close bottom sheet"
                style={{
                  minWidth: 44,
                  minHeight: 44,
                  alignItems: 'center',
                  justifyContent: 'center',
                }}
              >
                <Text variant="base" weight="semibold" color="muted">
                  ✕
                </Text>
              </Pressable>
            </View>
          ) : null}

          {/* Body Content */}
          <View>{children}</View>
        </Animated.View>
      </View>
    </Modal>
  );
};

// Helper for full screen absolute overlay
function ViewStyleSheetAbsoluteFill(): ViewStyle {
  return {
    position: 'absolute',
    left: 0,
    right: 0,
    top: 0,
    bottom: 0,
  };
}
