import React, { useMemo } from 'react';
import { View, ScrollView, StyleSheet, Alert } from 'react-native';
import { Text, Surface, Button, EmptyState, ListRow, ProgressBar } from '../components';
import type { RootStackScreenProps } from '../navigation/types';
import { useTheme } from '../theme/theme';
import { useCloudRemotes } from '../hooks/useCloudRemotes';
import { HardDrive, Shield, ShieldAlert, Trash2 } from 'lucide-react-native';

export function RemoteDetailScreen({ navigation, route }: RootStackScreenProps<'RemoteDetail'>) {
  const { remoteId } = route.params;
  const { colors, spacing } = useTheme();
  const { remotes, loading, deleteRemote } = useCloudRemotes();

  const remote = useMemo(() => remotes.find(r => r.id === remoteId), [remotes, remoteId]);

  const handleDelete = () => {
    Alert.alert(
      'Disconnect Remote',
      'Bereits hochgeladene Dateien bleiben in der Cloud erhalten. Möchten Sie wirklich fortfahren?',
      [
        { text: 'Cancel', style: 'cancel' },
        { 
          text: 'Disconnect', 
          style: 'destructive',
          onPress: async () => {
            try {
              await deleteRemote(remoteId);
              navigation.goBack();
            } catch {
              Alert.alert('Error', 'Failed to disconnect remote.');
            }
          }
        }
      ]
    );
  };

  if (loading && !remote) {
    return (
      <View style={[styles.center, { backgroundColor: colors.bg.canvas, padding: spacing.xl }]}>
        <Text>Loading...</Text>
      </View>
    );
  }

  if (!remote) {
    return (
      <View style={[styles.center, { backgroundColor: colors.bg.canvas, padding: spacing.xl }]}>
        <EmptyState
          icon={<HardDrive size={48} color={colors.text.muted} />}
          title="Remote Not Found"
          description="The requested cloud drive does not exist."
          actionLabel="Go Back"
          onAction={() => navigation.goBack()}
        />
      </View>
    );
  }

  const usagePercent = remote.total_space_bytes > 0 
    ? remote.used_space_bytes / remote.total_space_bytes 
    : 0;

  return (
    <ScrollView contentContainerStyle={{ padding: spacing.lg, backgroundColor: colors.bg.canvas, flexGrow: 1 }}>
      <Surface style={{ padding: spacing.lg, marginBottom: spacing.lg, alignItems: 'center' }}>
        <HardDrive size={48} color={colors.accent.default} style={{ marginBottom: spacing.md }} />
        <Text variant="xl" weight="bold">{remote.name}</Text>
        <Text variant="base" color="muted">{remote.provider.toUpperCase()}</Text>
      </Surface>

      <View style={{ marginBottom: spacing.xl }}>
        <Text variant="lg" weight="semibold" style={{ marginBottom: spacing.md }}>Storage</Text>
        <Surface style={{ padding: spacing.lg }}>
          <View style={{ flexDirection: 'row', justifyContent: 'space-between', marginBottom: spacing.sm }}>
            <Text variant="sm" color="muted">Used: {Math.round((remote.used_space_bytes || 0) / 1024 / 1024)} MB</Text>
            <Text variant="sm" color="muted">Total: {Math.round((remote.total_space_bytes || 0) / 1024 / 1024)} MB</Text>
          </View>
          <ProgressBar progress={usagePercent} color="accent" />
        </Surface>
      </View>

      <View style={{ marginBottom: spacing.xl }}>
        <Text variant="lg" weight="semibold" style={{ marginBottom: spacing.md }}>Security</Text>
        <ListRow
          title={remote.is_encrypted ? "Encrypted" : "Not Encrypted"}
          subtitle={remote.is_encrypted ? "Files are encrypted before upload." : "Files are uploaded as is."}
          leftIcon={remote.is_encrypted ? <Shield color={colors.status.ok} /> : <ShieldAlert color={colors.status.warn} />}
        />
      </View>

      <View style={{ marginTop: 'auto', paddingTop: spacing.xl }}>
        <Button 
          label="Disconnect Remote" 
          variant="danger" 
          fullWidth 
          icon={<Trash2 size={20} color={colors.text.inverse} />}
          onPress={handleDelete} 
        />
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  center: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
