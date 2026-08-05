import React, { useState } from 'react';
import { ScrollView, View, StyleSheet } from 'react-native';
import { useTheme, ThemeProvider } from '../theme/theme';
import { Text } from './Text';
import { Surface } from './Surface';
import { Button } from './Button';
import { IconButton } from './IconButton';
import { ListRow } from './ListRow';
import { ProgressRing } from './ProgressRing';
import { ProgressBar } from './ProgressBar';
import { Sheet } from './Sheet';
import { Toggle } from './Toggle';
import { EmptyState } from './EmptyState';
import { Badge } from './Badge';

const PreviewContent: React.FC = () => {
  const { colorScheme, colors, spacing, toggleColorScheme } = useTheme();

  // State for interactive component showcase
  const [clickCount, setClickCount] = useState(0);
  const [toggleVal, setToggleVal] = useState(true);
  const [progressVal, setProgressVal] = useState(0.65);
  const [isSheetOpen, setIsSheetOpen] = useState(false);

  const handleIncrementProgress = () => {
    setProgressVal((prev) => (prev >= 1 ? 0.1 : Math.round((prev + 0.15) * 100) / 100));
  };

  return (
    <ScrollView
      style={[styles.container, { backgroundColor: colors.bg.canvas }]}
      contentContainerStyle={{ padding: spacing.lg, gap: spacing.xl }}
    >
      {/* Header section with Theme Toggle */}
      <Surface elevation="surfaceRaised" padding="lg" border="subtle">
        <View style={styles.rowBetween}>
          <View>
            <Text variant="xl" weight="bold" color="primary">
              EchoVault Preview
            </Text>
            <Text variant="sm" color="muted">
              Mode: {colorScheme.toUpperCase()}
            </Text>
          </View>
          <Button
            label={`Switch to ${colorScheme === 'light' ? 'Dark' : 'Light'}`}
            onPress={toggleColorScheme}
            variant="secondary"
            size="sm"
          />
        </View>
      </Surface>

      {/* 1. Typography Showcase */}
      <Surface padding="lg" border="subtle">
        <Text variant="lg" weight="bold" color="accent" style={{ marginBottom: spacing.md }}>
          1. Text Typography Scale
        </Text>
        <View style={{ gap: spacing.xs }}>
          <Text variant="xl" weight="bold">
            XL (28pt) Bold Title
          </Text>
          <Text variant="lg" weight="semibold">
            LG (20pt) Semibold Heading
          </Text>
          <Text variant="base" weight="medium">
            Base (16pt) Medium Body Text
          </Text>
          <Text variant="sm" color="secondary">
            SM (14pt) Secondary Body Text
          </Text>
          <Text variant="xs" color="muted">
            XS (12pt) Muted Caption Text
          </Text>
        </View>
      </Surface>

      {/* 2. Surfaces Showcase */}
      <Surface padding="lg" border="subtle">
        <Text variant="lg" weight="bold" color="accent" style={{ marginBottom: spacing.md }}>
          2. Surface Elevations & Borders
        </Text>
        <View style={{ gap: spacing.md }}>
          <Surface elevation="canvas" padding="md" border="subtle">
            <Text variant="sm" color="secondary">
              Elevation: Canvas with subtle border
            </Text>
          </Surface>
          <Surface elevation="surface" padding="md" border="default">
            <Text variant="sm" color="primary">
              Elevation: Surface with default border
            </Text>
          </Surface>
          <Surface elevation="surfaceRaised" padding="md">
            <Text variant="sm" color="primary">
              Elevation: Surface Raised without border
            </Text>
          </Surface>
        </View>
      </Surface>

      {/* 3. Button Variants & Sizes */}
      <Surface padding="lg" border="subtle">
        <Text variant="lg" weight="bold" color="accent" style={{ marginBottom: spacing.sm }}>
          3. Button Components
        </Text>
        <Text variant="sm" color="muted" style={{ marginBottom: spacing.md }}>
          Count: {clickCount} | Touch target: &gt;= 44pt
        </Text>
        <View style={{ gap: spacing.sm, alignItems: 'flex-start' }}>
          <Button
            label={`Primary Button (${clickCount})`}
            onPress={() => setClickCount((c) => c + 1)}
            variant="primary"
          />
          <Button
            label="Secondary Button"
            onPress={() => setClickCount((c) => c + 1)}
            variant="secondary"
          />
          <Button
            label="Outline Button"
            onPress={() => setClickCount((c) => c + 1)}
            variant="outline"
          />
          <Button
            label="Danger Button"
            onPress={() => setClickCount((c) => c + 1)}
            variant="danger"
          />
          <Button
            label="Loading Button"
            onPress={() => {}}
            loading
            variant="primary"
          />
        </View>
      </Surface>

      {/* 4. IconButton Showcase */}
      <Surface padding="lg" border="subtle">
        <Text variant="lg" weight="bold" color="accent" style={{ marginBottom: spacing.md }}>
          4. IconButtons (&gt;= 44pt Target)
        </Text>
        <View style={{ flexDirection: 'row', gap: spacing.md, alignItems: 'center' }}>
          <IconButton
            icon={<Text variant="base">★</Text>}
            onPress={() => setClickCount((c) => c + 1)}
            accessibilityLabel="Star action"
            variant="primary"
          />
          <IconButton
            icon={<Text variant="base">⚙</Text>}
            onPress={() => setClickCount((c) => c + 1)}
            accessibilityLabel="Settings action"
            variant="secondary"
          />
          <IconButton
            icon={<Text variant="base">⚡</Text>}
            onPress={() => setClickCount((c) => c + 1)}
            accessibilityLabel="Zap action"
            variant="outline"
          />
          <IconButton
            icon={<Text variant="base">✕</Text>}
            onPress={() => setClickCount((c) => c + 1)}
            accessibilityLabel="Close action"
            variant="ghost"
          />
        </View>
      </Surface>

      {/* 5. ListRow Showcase */}
      <Surface border="subtle" borderRadius="lg" style={{ overflow: 'hidden' }}>
        <View style={{ padding: spacing.lg, paddingBottom: spacing.xs }}>
          <Text variant="lg" weight="bold" color="accent">
            5. ListRows
          </Text>
        </View>
        <ListRow
          title="Account Security"
          subtitle="Two-factor authentication enabled"
          leftIcon={<Text variant="base">🔒</Text>}
          rightIcon={<Text variant="base" color="muted">›</Text>}
          onPress={() => {}}
        />
        <ListRow
          title="Storage Limit"
          value="12.4 GB / 50 GB"
          leftIcon={<Text variant="base">☁</Text>}
          showBorder={false}
          onPress={() => {}}
        />
      </Surface>

      {/* 6. Progress Indicators */}
      <Surface padding="lg" border="subtle">
        <Text variant="lg" weight="bold" color="accent" style={{ marginBottom: spacing.md }}>
          6 & 7. ProgressRing & ProgressBar
        </Text>
        <View style={{ gap: spacing.md }}>
          <View style={styles.rowBetween}>
            <ProgressRing progress={progressVal} showValue size={56} />
            <Button label="Cycle Progress" onPress={handleIncrementProgress} variant="outline" size="sm" />
          </View>
          <ProgressBar progress={progressVal} color="accent" />
          <ProgressBar progress={0.9} color="warn" />
          <ProgressBar progress={0.3} color="error" />
          <ProgressBar progress={1.0} color="ok" />
        </View>
      </Surface>

      {/* 8. Sheet Showcase */}
      <Surface padding="lg" border="subtle">
        <Text variant="lg" weight="bold" color="accent" style={{ marginBottom: spacing.md }}>
          8. Bottom Sheet Modal
        </Text>
        <Button
          label="Open Bottom Sheet"
          onPress={() => setIsSheetOpen(true)}
          variant="primary"
        />
        <Sheet
          isOpen={isSheetOpen}
          onClose={() => setIsSheetOpen(false)}
          title="EchoVault Bottom Sheet"
        >
          <View style={{ paddingVertical: spacing.md, gap: spacing.md }}>
            <Text variant="base" color="secondary">
              This is a reanimated bottom sheet component with animated backdrop and sheet transition.
            </Text>
            <Button
              label="Dismiss Sheet"
              onPress={() => setIsSheetOpen(false)}
              variant="secondary"
              fullWidth
            />
          </View>
        </Sheet>
      </Surface>

      {/* 9. Toggle Showcase */}
      <Surface padding="lg" border="subtle">
        <Text variant="lg" weight="bold" color="accent" style={{ marginBottom: spacing.md }}>
          9. Toggle Switch
        </Text>
        <Toggle
          label="Enable Push Notifications"
          value={toggleVal}
          onValueChange={setToggleVal}
        />
      </Surface>

      {/* 10. Badges Showcase */}
      <Surface padding="lg" border="subtle">
        <Text variant="lg" weight="bold" color="accent" style={{ marginBottom: spacing.md }}>
          10. Badges
        </Text>
        <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm }}>
          <Badge label="Default" variant="default" />
          <Badge label="Accent" variant="accent" />
          <Badge label="Status OK" variant="ok" />
          <Badge label="Warning" variant="warn" />
          <Badge label="Error" variant="error" />
          <Badge label="Outline" variant="outline" />
        </View>
      </Surface>

      {/* 11. EmptyState Showcase */}
      <Surface padding="lg" border="subtle">
        <Text variant="lg" weight="bold" color="accent" style={{ marginBottom: spacing.md }}>
          11. EmptyState
        </Text>
        <EmptyState
          title="No Vault Files Found"
          description="Your encrypted vault is currently empty. Start by uploading or creating your first secure document."
          icon={<Text variant="xl">📁</Text>}
          actionLabel="Add Document"
          onAction={() => {}}
        />
      </Surface>
    </ScrollView>
  );
};

export const Preview: React.FC = () => {
  return (
    <ThemeProvider>
      <PreviewContent />
    </ThemeProvider>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  rowBetween: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
});
