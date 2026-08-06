import React from 'react';
import { View, FlatList, StyleSheet } from 'react-native';
import { Surface, ListRow, Toggle, EmptyState, ProgressRing } from '../components';
import { useSyncRules } from '../hooks/useSyncRules';
import { Server, Settings } from 'lucide-react-native';
import { useTheme } from '../theme/theme';

export function SyncRulesScreen() {
  const { rules, loading, error, toggleRule } = useSyncRules();
  const { colors } = useTheme();

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
          icon={<Settings color={colors.status.error} size={48} />}
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
          icon={<Settings color={colors.text.muted} size={48} />}
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
            leftIcon={<Server size={24} color={colors.text.secondary} />}
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
