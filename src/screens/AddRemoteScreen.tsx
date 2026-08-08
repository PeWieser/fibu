import React, { useState, useCallback } from 'react';
import {
  View,
  ScrollView,
  TextInput,
  StyleSheet,
  TouchableOpacity,
  Alert,
} from 'react-native';
import { Text, Button } from '../components';
import type { RootStackScreenProps } from '../navigation/types';
import { useTheme } from '../theme/theme';
import { useCloudRemotes } from '../hooks/useCloudRemotes';
import type { Provider } from '../types';

const PROVIDERS: { label: string; value: Provider }[] = [
  { label: 'Google Drive', value: 'drive' },
  { label: 'OneDrive', value: 'onedrive' },
  { label: 'Dropbox', value: 'dropbox' },
  { label: 'Mega', value: 'mega' },
];

export function AddRemoteScreen({ navigation }: RootStackScreenProps<'AddRemote'>) {
  const { colors, spacing, borderRadius: radius } = useTheme();
  const { addRemote } = useCloudRemotes();

  const [name, setName] = useState('');
  const [provider, setProvider] = useState<Provider>('drive');
  const [rcloneConfig, setRcloneConfig] = useState('');
  const [saving, setSaving] = useState(false);

  const isValid = name.trim().length > 0 && rcloneConfig.trim().length > 0;

  const handleSave = useCallback(async () => {
    if (!isValid) return;
    setSaving(true);
    try {
      await addRemote({
        name: name.trim(),
        provider,
        rclone_config: rcloneConfig.trim(),
        is_encrypted: false,
        total_space_bytes: 0,
        used_space_bytes: 0,
      });
      navigation.goBack();
    } catch (e) {
      Alert.alert('Error', e instanceof Error ? e.message : 'Failed to add drive.');
    } finally {
      setSaving(false);
    }
  }, [isValid, name, provider, rcloneConfig, addRemote, navigation]);

  const inputStyle = {
    backgroundColor: colors.bg.surface,
    borderColor: colors.border.default,
    color: colors.text.primary,
    borderRadius: radius.sm,
    borderWidth: 1,
    padding: spacing.md,
    fontSize: 15,
    minHeight: 48,
  };

  return (
    <ScrollView
      contentContainerStyle={[styles.container, { backgroundColor: colors.bg.canvas, padding: spacing.lg }]}
      keyboardShouldPersistTaps="handled"
    >
      {/* Name */}
      <View style={{ marginBottom: spacing.lg }}>
        <Text variant="sm" weight="semibold" style={{ marginBottom: spacing.xs }}>
          Name
        </Text>
        <TextInput
          accessibilityLabel="Drive name"
          placeholder="My Cloud Drive"
          placeholderTextColor={colors.text.muted}
          value={name}
          onChangeText={setName}
          style={inputStyle}
          autoFocus
          returnKeyType="next"
        />
      </View>

      {/* Provider */}
      <View style={{ marginBottom: spacing.lg }}>
        <Text variant="sm" weight="semibold" style={{ marginBottom: spacing.xs }}>
          Provider
        </Text>
        <View style={{ gap: spacing.xs }}>
          {PROVIDERS.map((p) => {
            const selected = provider === p.value;
            return (
              <TouchableOpacity
                key={p.value}
                accessibilityRole="radio"
                accessibilityLabel={p.label}
                accessibilityState={{ selected }}
                onPress={() => setProvider(p.value)}
                style={[
                  styles.providerRow,
                  {
                    backgroundColor: selected ? colors.accent.muted : colors.bg.surface,
                    borderColor: selected ? colors.accent.default : colors.border.default,
                    borderRadius: radius.sm,
                    padding: spacing.md,
                    minHeight: 44,
                  },
                ]}
              >
                <Text
                  variant="base"
                  weight={selected ? 'semibold' : 'normal'}
                  color={selected ? 'accent' : 'primary'}
                >
                  {p.label}
                </Text>
              </TouchableOpacity>
            );
          })}
        </View>
      </View>

      {/* rclone config */}
      <View style={{ marginBottom: spacing.xl }}>
        <Text variant="sm" weight="semibold" style={{ marginBottom: spacing.xs }}>
          rclone Config (JSON)
        </Text>
        <TextInput
          accessibilityLabel="rclone config"
          placeholder={'{\n  "type": "drive",\n  "token": "..."\n}'}
          placeholderTextColor={colors.text.muted}
          value={rcloneConfig}
          onChangeText={setRcloneConfig}
          multiline
          numberOfLines={6}
          style={[inputStyle, { minHeight: 120, textAlignVertical: 'top', fontFamily: 'monospace' }]}
        />
        <Text variant="xs" color="muted" style={{ marginTop: spacing.xs }}>
          Paste the rclone backend config block as JSON.
        </Text>
      </View>

      <Button
        label={saving ? 'Saving…' : 'Add Drive'}
        variant="primary"
        fullWidth
        onPress={handleSave}
        disabled={!isValid || saving}
      />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flexGrow: 1,
  },
  providerRow: {
    borderWidth: 1,
    flexDirection: 'row',
    alignItems: 'center',
  },
});
