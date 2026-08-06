import React from 'react';
import { View, StyleSheet, Alert, ScrollView } from 'react-native';
import { Surface, Text, ListRow, Button } from '../components';
import { Settings as SettingsIcon, Info, Database, AlertTriangle } from 'lucide-react-native';
import { useTheme } from '../theme/theme';

export function SettingsScreen() {
  const { colors, borderRadius } = useTheme();

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
      <ScrollView contentContainerStyle={styles.content}>
        
        <View style={styles.section}>
          <Text variant="lg" weight="bold" style={styles.sectionTitle}>About</Text>
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

        <View style={styles.section}>
          <Text variant="lg" weight="bold" style={styles.sectionTitle}>Danger Zone</Text>
          
          <View style={[styles.dangerZone, { borderColor: colors.status.error, borderRadius: borderRadius.lg }]}>
            <View style={styles.dangerRow}>
              <Database size={24} color={colors.status.error} />
              <View style={styles.dangerText}>
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
  content: {
    padding: 16,
  },
  section: {
    marginBottom: 32,
  },
  sectionTitle: {
    marginBottom: 16,
  },
  dangerZone: {
    borderWidth: 1,
    padding: 16,
  },
  dangerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 16,
  },
  dangerText: {
    marginLeft: 12,
    flex: 1,
  },
});
