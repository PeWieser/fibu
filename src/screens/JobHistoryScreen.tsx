import React from 'react';
import { View, FlatList, StyleSheet } from 'react-native';
import { Surface, ListRow, EmptyState, ProgressRing } from '../components';
import { useSyncJobs } from '../hooks/useSyncJobs';
import { History, CheckCircle, XCircle, Clock } from 'lucide-react-native';

export function JobHistoryScreen() {
  const { history, loading, error } = useSyncJobs();

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
          icon={<History color="#EF4444" size={48} />}
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
          icon={<History color="#9CA3AF" size={48} />}
          title="No Job History"
          description="There are no recent sync jobs to display."
        />
      </View>
    );
  }

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'SYNCED':
        return <CheckCircle size={24} color="#10B981" />;
      case 'FAILED':
        return <XCircle size={24} color="#EF4444" />;
      case 'PENDING':
      case 'UPLOADING':
        return <Clock size={24} color="#3B82F6" />;
      default:
        return <Clock size={24} color="#6B7280" />;
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
