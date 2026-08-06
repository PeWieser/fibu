import React from 'react';
import { View, ScrollView, StyleSheet } from 'react-native';
import { Text, Button, Surface } from '../components';
import type { RootStackScreenProps } from '../navigation/types';
import { Cloud, Server, Shield } from 'lucide-react-native';
import { useTheme } from '../theme/theme';

export function OnboardingScreen({ navigation }: RootStackScreenProps<'Onboarding'>) {
  const { colors, spacing } = useTheme();

  const handleSkip = () => {
    navigation.replace('Main');
  };

  const handleConnect = () => {
    navigation.replace('Main', { screen: 'CloudDrives' });
  };

  return (
    <ScrollView contentContainerStyle={[styles.container, { backgroundColor: colors.bg.canvas, padding: spacing.xl }]}>
      <View style={styles.header}>
        <Text variant="xl" weight="bold">Welcome to EchoVault</Text>
        <Text variant="base" color="muted" align="center" style={{ marginTop: spacing.md }}>
          Secure, seamless syncing between your local device and cloud storage.
        </Text>
      </View>

      <View style={[styles.features, { gap: spacing.lg }]}>
        <Surface style={[styles.featureCard, { padding: spacing.lg }]}>
          <Cloud size={32} color={colors.accent.default} />
          <Text variant="lg" weight="semibold" style={{ marginTop: spacing.md }}>Connect Clouds</Text>
          <Text variant="base" color="muted" align="center" style={{ marginTop: spacing.sm }}>
            Add WebDAV, Nextcloud, S3, or SFTP to keep your files in sync.
          </Text>
        </Surface>

        <Surface style={[styles.featureCard, { padding: spacing.lg }]}>
          <Shield size={32} color={colors.accent.default} />
          <Text variant="lg" weight="semibold" style={{ marginTop: spacing.md }}>Privacy First</Text>
          <Text variant="base" color="muted" align="center" style={{ marginTop: spacing.sm }}>
            Your data is stored securely. Optionally encrypt files before uploading.
          </Text>
        </Surface>

        <Surface style={[styles.featureCard, { padding: spacing.lg }]}>
          <Server size={32} color={colors.accent.default} />
          <Text variant="lg" weight="semibold" style={{ marginTop: spacing.md }}>Automated Sync</Text>
          <Text variant="base" color="muted" align="center" style={{ marginTop: spacing.sm }}>
            Set up rules for folders to sync automatically in the background.
          </Text>
        </Surface>
      </View>

      <View style={[styles.actions, { gap: spacing.md }]}>
        <Button label="Connect a Cloud Drive" variant="primary" fullWidth onPress={handleConnect} />
        <Button label="Skip for now" variant="ghost" fullWidth onPress={handleSkip} />
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flexGrow: 1,
    alignItems: 'center',
    justifyContent: 'space-around',
  },
  header: {
    alignItems: 'center',
    marginBottom: 32,
    marginTop: 32,
  },
  features: {
    width: '100%',
    marginBottom: 32,
  },
  featureCard: {
    alignItems: 'center',
  },
  actions: {
    width: '100%',
  },
});
