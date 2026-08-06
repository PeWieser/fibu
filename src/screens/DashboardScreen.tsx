import React from 'react';
import { View, ScrollView, ActivityIndicator } from 'react-native';
import { Text, Surface, EmptyState, ListRow } from '../components';
import { useSyncJobs } from '../hooks/useSyncJobs';
import { useSyncRules } from '../hooks/useSyncRules';
import { AlertCircle, CheckCircle2, Clock, Check } from 'lucide-react-native';
import { useTheme } from '../theme/theme';

export function DashboardScreen() {
  const { history, pending, failed, loading: jobsLoading, error: jobsError, refresh: refreshJobs } = useSyncJobs();
  const { rules, loading: rulesLoading, error: rulesError, refresh: refreshRules } = useSyncRules();
  const { colors, spacing } = useTheme();

  const loading = jobsLoading || rulesLoading;
  const error = jobsError || rulesError;

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
          title="Failed to load dashboard"
          description={error.message}
          icon={<AlertCircle color={colors.status.error} size={32} />}
          actionLabel="Retry"
          onAction={() => {
            refreshJobs();
            refreshRules();
          }}
        />
      </View>
    );
  }

  const recentSynced = history.filter(h => h.status === 'SYNCED').slice(0, 5);

  return (
    <ScrollView style={{ flex: 1, backgroundColor: colors.bg.canvas }}>
      <View style={{ padding: spacing.lg, gap: spacing.lg }}>
        <Text variant="xl">Dashboard</Text>

        <View style={{ flexDirection: 'row', gap: spacing.md, flexWrap: 'wrap' }}>
          <Surface elevation="surface" padding="md" borderRadius="lg" border style={{ flex: 1, minWidth: 100 }}>
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.sm, marginBottom: spacing.sm }}>
              <Clock size={20} color={colors.text.secondary} />
              <Text variant="sm" color="secondary">Pending</Text>
            </View>
            <Text variant="lg" weight="bold">{pending.length}</Text>
          </Surface>

          <Surface elevation="surface" padding="md" borderRadius="lg" border style={{ flex: 1, minWidth: 100 }}>
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.sm, marginBottom: spacing.sm }}>
              <AlertCircle size={20} color={colors.status.error} />
              <Text variant="sm" color="secondary">Failed</Text>
            </View>
            <Text variant="lg" weight="bold">{failed.length}</Text>
          </Surface>

          <Surface elevation="surface" padding="md" borderRadius="lg" border style={{ flex: 1, minWidth: 100 }}>
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: spacing.sm, marginBottom: spacing.sm }}>
              <CheckCircle2 size={20} color={colors.text.primary} />
              <Text variant="sm" color="secondary">Rules</Text>
            </View>
            <Text variant="lg" weight="bold">{rules.length}</Text>
          </Surface>
        </View>

        <Surface elevation="surface" borderRadius="lg" border>
          <View style={{ padding: spacing.md, borderBottomWidth: 1, borderBottomColor: colors.border.subtle }}>
            <Text variant="lg" weight="semibold">Recently Synced</Text>
          </View>
          
          {recentSynced.length === 0 ? (
            <View style={{ padding: spacing.xl, alignItems: 'center' }}>
              <Text variant="base" color="muted">No recent synced files</Text>
            </View>
          ) : (
            recentSynced.map((file, i) => (
              <ListRow
                key={file.id}
                title={file.local_uri.split('/').pop() || 'Unknown File'}
                subtitle={new Date(file.updated_at).toLocaleString()}
                leftIcon={<Check size={24} color={colors.status.ok} />}
                showBorder={i < recentSynced.length - 1}
              />
            ))
          )}
        </Surface>
      </View>
    </ScrollView>
  );
}
