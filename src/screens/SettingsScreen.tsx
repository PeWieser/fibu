import React from 'react';
import { View, StyleSheet, Alert, ScrollView } from 'react-native';
import { Surface, Text, ListRow, Button } from '../components';
import { Settings as SettingsIcon, Info, Database, AlertTriangle } from 'lucide-react-native';
import { useTheme } from '../theme/theme';

export function SettingsScreen() {
  const { colors, borderRadius, spacing } = useTheme();

  const handleResetIndex = () => {
    Alert.alert(
      "Reset Local Index",
      "Der lokale Sync-Status wird zurückgesetzt. Beim nächsten Sync werden alle Dateien erneut geprüft.",
      [
        { text: "Cancel", style: "cancel" },
        { 
          text: "Reset", 
          style: "destructive", 
          onPress: () => {
            // Placeholder for actual reset logic
          } 
        }
      ]
    );
  };

  return (
    <Surface style={styles.container}>
      <ScrollView contentContainerStyle={{ padding: spacing.lg }}>
        
        <View style={{ marginBottom: spacing['2xl'] }}>
          <Text variant="lg" weight="bold" style={{ marginBottom: spacing.lg }}>About</Text>
          <ListRow
            title="App Version"
            value="1.0.0"
            leftIcon={<Info size={24} color={colors.text.muted} />}
          />
          <ListRow
            title="Environment"
            value="Development"
            leftIcon={<SettingsIcon size={24} color={colors.text.muted} />}
          />
        </View>

        <View style={{ marginBottom: spacing['2xl'] }}>
          <Text variant="lg" weight="bold" style={{ marginBottom: spacing.lg }}>Danger Zone</Text>
          
          <View style={[styles.dangerZone, { borderColor: colors.status.error, borderRadius: borderRadius.lg, padding: spacing.lg }]}>
            <View style={[styles.dangerRow, { marginBottom: spacing.lg }]}>
              <Database size={24} color={colors.status.error} />
              <View style={{ marginLeft: spacing.md, flex: 1 }}>
                <Text variant="base" weight="semibold" color="primary">Reset Local Index</Text>
                <Text variant="sm" color="muted">Clear local sync states. Files will be re-checked.</Text>
              </View>
            </View>
            
            <Button
              label="Reset Database"
              variant="secondary"
              onPress={handleResetIndex}
              icon={<AlertTriangle size={20} color={colors.status.error} />}
            />
          </View>
        </View>

      </ScrollView>
    </Surface>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  dangerZone: {
    borderWidth: 1,
  },
  dangerRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
});
