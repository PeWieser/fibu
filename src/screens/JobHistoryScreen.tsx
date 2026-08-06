import React from 'react';
import { View, FlatList, StyleSheet } from 'react-native';
import { Surface, ListRow, EmptyState, ProgressRing } from '../components';
import { useSyncJobs } from '../hooks/useSyncJobs';
import { History, CheckCircle, XCircle, Clock } from 'lucide-react-native';
import { useTheme } from '../theme/theme';

export function JobHistoryScreen() {
  const { history, loading, error } = useSyncJobs();
  const { colors } = useTheme();

  if (loading && history.length === 0) {
    return (
      <View style={styles.center}>
        <ProgressRing progress={0} />
      </View>
    );
  }

  if (error) {
    return (
      <View style={styles.center}>
        <EmptyState 
          icon={<History color={colors.status.error} size={48} />}
          title="Error loading history"
          description={error.message}
        />
      </View>
    );
  }

  if (history.length === 0) {
    return (
      <View style={styles.center}>
        <EmptyState 
          icon={<History color={colors.text.muted} size={48} />}
          title="No Job History"
          description="There are no recent sync jobs to display."
        />
      </View>
    );
  }

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'SYNCED':
        return <CheckCircle size={24} color={colors.status.ok} />;
      case 'FAILED':
        return <XCircle size={24} color={colors.status.error} />;
      case 'PENDING':
      case 'UPLOADING':
        return <Clock size={24} color={colors.accent.default} />;
      default:
        return <Clock size={24} color={colors.text.secondary} />;
    }
  };

  return (
    <Surface style={styles.container}>
      <FlatList
        data={history}
        keyExtractor={item => item.id}
        contentContainerStyle={styles.listContent}
        renderItem={({ item }) => (
          <ListRow
            title={item.local_uri.split('/').pop() || 'Unknown File'}
            subtitle={`Status: ${item.status}${item.last_error ? ` - ${item.last_error}` : ''}`}
            leftIcon={getStatusIcon(item.status)}
          />
        )}
      />
    </Surface>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  center: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 16,
  },
  listContent: {
    padding: 16,
  },
});
