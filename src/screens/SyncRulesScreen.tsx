import React from 'react';
import { View, FlatList, StyleSheet } from 'react-native';
import { Surface, ListRow, Toggle, EmptyState, ProgressRing } from '../components';
import { useSyncRules } from '../hooks/useSyncRules';
import { Server, Settings } from 'lucide-react-native';

export function SyncRulesScreen() {
  const { rules, loading, error, toggleRule } = useSyncRules();

  if (loading && rules.length === 0) {
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
          icon={<Settings color="#EF4444" size={48} />}
          title="Error loading rules"
          description={error.message}
        />
      </View>
    );
  }

  if (rules.length === 0) {
    return (
      <View style={styles.center}>
        <EmptyState 
          icon={<Settings color="#9CA3AF" size={48} />}
          title="No Sync Rules"
          description="You haven't configured any sync rules yet."
        />
      </View>
    );
  }

  return (
    <Surface style={styles.container}>
      <FlatList
        data={rules}
        keyExtractor={item => item.id}
        contentContainerStyle={styles.listContent}
        renderItem={({ item }) => (
          <ListRow
            title={`Album: ${item.source_album_id} ➔ ${item.target_remote_id}`}
            subtitle={`${item.sync_mode} - ${item.media_type}`}
            leftIcon={<Server size={24} color="#6B7280" />}
            rightIcon={
              <Toggle
                value={item.is_enabled}
                onValueChange={(val) => toggleRule(item.id, val)}
              />
            }
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
