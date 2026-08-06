import React from 'react';
import { View, ScrollView, ActivityIndicator, Alert } from 'react-native';
import { Text, Surface, EmptyState, ListRow, IconButton } from '../components';
import { useCloudRemotes } from '../hooks/useCloudRemotes';
import { Cloud, AlertCircle, Plus, HardDrive, Trash2 } from 'lucide-react-native';
import { useTheme } from '../theme/theme';

export function CloudDrivesScreen() {
  const { remotes, loading, error, refresh, deleteRemote } = useCloudRemotes();
  const { colors, spacing } = useTheme();

  const handleDelete = (id: string, name: string) => {
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
              await deleteRemote(id);
            } catch {
              Alert.alert('Error', `Failed to disconnect remote "${name}".`);
            }
          },
        },
      ]
    );
  };

  if (loading) {
    return (
      <View style={{ flex: 1, justifyContent: 'center', alignItems: 'center', backgroundColor: colors.bg.canvas }}>
        <ActivityIndicator size="large" color={colors.text.primary} />
      </View>
    );
  }

  if (error) {
    return (
      <View style={{ flex: 1, padding: spacing.lg, justifyContent: 'center', backgroundColor: colors.bg.canvas }}>
        <EmptyState 
          title="Failed to load remotes"
          description={error.message}
          icon={<AlertCircle color={colors.status.error} size={32} />}
          actionLabel="Retry"
          onAction={refresh}
        />
      </View>
    );
  }

  return (
    <ScrollView style={{ flex: 1, backgroundColor: colors.bg.canvas }}>
      <View style={{ padding: spacing.lg, gap: spacing.lg }}>
        <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }}>
          <Text variant="xl">Cloud Drives</Text>
          <IconButton 
            icon={<Plus size={24} color={colors.text.primary} />} 
            onPress={() => { /* TODO: Add remote */ }} 
            accessibilityLabel="Add Remote"
          />
        </View>

        {remotes.length === 0 ? (
          <EmptyState 
            title="No Cloud Drives"
            description="Connect a cloud drive to start syncing your files."
            icon={<Cloud color={colors.text.secondary} size={48} />}
            actionLabel="Add Drive"
            onAction={() => { /* TODO: Add remote */ }}
          />
        ) : (
          <Surface elevation="surface" borderRadius="lg" border>
            {remotes.map((remote, i) => (
              <ListRow
                key={remote.id}
                title={remote.name}
                subtitle={`${remote.provider} • ${(remote.used_space_bytes / 1024 / 1024 / 1024).toFixed(1)}GB used`}
                leftIcon={<HardDrive size={24} color={colors.text.primary} />}
                rightIcon={
                  <IconButton 
                    icon={<Trash2 size={20} color={colors.status.error} />}
                    onPress={() => handleDelete(remote.id, remote.name)}
                    accessibilityLabel="Delete Remote"
                  />
                }
                showBorder={i < remotes.length - 1}
              />
            ))}
          </Surface>
        )}
      </View>
    </ScrollView>
  );
}
